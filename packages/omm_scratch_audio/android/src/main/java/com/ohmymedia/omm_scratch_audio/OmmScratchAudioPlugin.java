package com.ohmymedia.omm_scratch_audio;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class OmmScratchAudioPlugin
        implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String TAG = "OmmScratchAudio";
    private static final ScratchAudioEngine ENGINE = new ScratchAudioEngine();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "omm/scratch_audio");
        channel.setMethodCallHandler(this);
        ENGINE.setApplicationContext(binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "prepare":
                    prepare(call, result);
                    break;
                case "start":
                    Number positionMs = call.argument("positionMs");
                    Boolean autoplay = call.argument("autoplay");
                    ENGINE.start(
                            positionMs == null ? 0 : positionMs.doubleValue(),
                            autoplay == null || autoplay
                    );
                    result.success(null);
                    break;
                case "play":
                    ENGINE.play();
                    result.success(null);
                    break;
                case "pause":
                    ENGINE.pause();
                    result.success(null);
                    break;
                case "seek":
                    Number seekPositionMs = call.argument("positionMs");
                    ENGINE.seek(seekPositionMs == null ? 0 : seekPositionMs.doubleValue());
                    result.success(null);
                    break;
                case "setRate":
                    Number rate = call.argument("rate");
                    ENGINE.setRate(rate == null ? 1 : rate.floatValue());
                    result.success(null);
                    break;
                case "state":
                    result.success(ENGINE.state());
                    break;
                case "stop":
                    ENGINE.stop();
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception error) {
            result.error("SCRATCH_AUDIO", message(error), null);
        }
    }

    private void prepare(MethodCall call, MethodChannel.Result result) {
        String source = call.argument("source");
        if (source == null || source.trim().isEmpty()) {
            result.error("SCRATCH_PREPARE", "Missing audio source", null);
            return;
        }
        ENGINE.prepare(source, headers(call.argument("headers")), new PrepareCallback() {
            @Override
            public void success(Map<String, Object> value) {
                mainHandler.post(() -> result.success(value));
            }

            @Override
            public void error(Exception error) {
                mainHandler.post(() ->
                        result.error("SCRATCH_PREPARE", message(error), null));
            }
        });
    }

    private static Map<String, String> headers(Object raw) {
        if (!(raw instanceof Map)) return Collections.emptyMap();
        Map<?, ?> input = (Map<?, ?>) raw;
        Map<String, String> result = new HashMap<>();
        for (Map.Entry<?, ?> entry : input.entrySet()) {
            if (entry.getKey() != null && entry.getValue() != null) {
                result.put(entry.getKey().toString(), entry.getValue().toString());
            }
        }
        return result;
    }

    private static String message(Exception error) {
        String value = error.getMessage();
        return value == null || value.isEmpty() ? error.getClass().getSimpleName() : value;
    }

    private interface PrepareCallback {
        void success(Map<String, Object> value);

        void error(Exception error);
    }

    private static final class ScratchAudioEngine {
        private static final int CHUNK_FRAMES = 256;

        private final ExecutorService decoder = Executors.newSingleThreadExecutor();
        private final Object lifecycleLock = new Object();
        private volatile Context applicationContext;
        private volatile File preparedSourceFile;
        private boolean audioFocusHeld;

        private volatile byte[] pcm;
        private volatile int sampleRate;
        private volatile int channels;
        private volatile int frameCount;
        private volatile double sourceFrame;
        private volatile float rate = 1;
        private volatile float currentRate = 1;
        private volatile boolean playing;
        private volatile AudioTrack audioTrack;
        private volatile int lastWriteResult = AudioTrack.ERROR_INVALID_OPERATION;
        private Thread renderThread;
        private final AudioManager.OnAudioFocusChangeListener audioFocusChangeListener = change -> {
            if (change != AudioManager.AUDIOFOCUS_LOSS
                    && change != AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                return;
            }
            synchronized (lifecycleLock) {
                playing = false;
                if (audioTrack != null) audioTrack.pause();
            }
        };

        void setApplicationContext(Context context) {
            applicationContext = context.getApplicationContext();
        }

        void prepare(
                String source,
                Map<String, String> headers,
                PrepareCallback callback
        ) {
            decoder.execute(() -> {
                File localSource = null;
                boolean temporarySource = false;
                try {
                    localSource = materializeSource(source, headers);
                    temporarySource = localSource != null
                            && localSource.equals(preparedSourceFile);
                    DecodedPcm decoded = decode(localSource);
                    synchronized (lifecycleLock) {
                        releaseTrackLocked();
                        pcm = decoded.bytes;
                        sampleRate = decoded.sampleRate;
                        channels = decoded.channels;
                        frameCount = decoded.frameCount;
                        sourceFrame = 0;
                        rate = 1;
                        currentRate = 1;
                        playing = false;
                        createTrackLocked();
                        startRenderThreadLocked();
                        Log.i(TAG, "PCM ready: " + sampleRate + "Hz, "
                                + channels + "ch, " + frameCount + " frames");
                    }
                    callback.success(state());
                } catch (Exception error) {
                    callback.error(error);
                } finally {
                    if (temporarySource) {
                        if (localSource.equals(preparedSourceFile)) {
                            preparedSourceFile = null;
                        }
                        deleteQuietly(localSource);
                    }
                }
            });
        }

        void start(double positionMs, boolean autoplay) {
            synchronized (lifecycleLock) {
                ensureReadyLocked();
                sourceFrame = clampFrame(positionMs / 1000 * sampleRate);
                currentRate = rate;
                startRenderThreadLocked();
                audioTrack.pause();
                audioTrack.flush();
                if (autoplay) {
                    requestAudioFocusLocked();
                    audioTrack.play();
                }
                playing = autoplay;
                Log.i(TAG, "PCM output started: rate=" + rate
                        + ", autoplay=" + autoplay);
            }
        }

        void play() {
            synchronized (lifecycleLock) {
                ensureReadyLocked();
                startRenderThreadLocked();
                requestAudioFocusLocked();
                audioTrack.play();
                playing = true;
            }
        }

        void pause() {
            synchronized (lifecycleLock) {
                playing = false;
                if (audioTrack != null) audioTrack.pause();
                abandonAudioFocusLocked();
            }
        }

        void seek(double positionMs) {
            synchronized (lifecycleLock) {
                ensureReadyLocked();
                boolean resume = playing;
                playing = false;
                audioTrack.pause();
                audioTrack.flush();
                sourceFrame = clampFrame(positionMs / 1000 * sampleRate);
                currentRate = rate;
                if (resume) {
                    requestAudioFocusLocked();
                    audioTrack.play();
                    playing = true;
                }
            }
        }

        void setRate(float nextRate) {
            if (!Float.isFinite(nextRate)) return;
            rate = Math.max(-8, Math.min(8, nextRate));
        }

        void stop() {
            synchronized (lifecycleLock) {
                playing = false;
                if (audioTrack != null) {
                    audioTrack.pause();
                    audioTrack.flush();
                }
                abandonAudioFocusLocked();
            }
        }

        Map<String, Object> state() {
            Map<String, Object> value = new HashMap<>();
            value.put("positionMs", sampleRate <= 0 ? 0 : sourceFrame * 1000 / sampleRate);
            value.put("durationMs", sampleRate <= 0 ? 0 : frameCount * 1000.0 / sampleRate);
            value.put("rate", (double) rate);
            value.put("playing", playing);
            value.put("ready", pcm != null && frameCount > 1);
            value.put("outputReady", audioTrack != null
                    && audioTrack.getState() == AudioTrack.STATE_INITIALIZED);
            value.put("lastWriteResult", lastWriteResult);
            return value;
        }

        private void ensureReadyLocked() {
            if (pcm == null || audioTrack == null || frameCount <= 1) {
                throw new IllegalStateException("Scratch audio is not prepared");
            }
        }

        private void createTrackLocked() {
            int mask = channels == 1
                    ? AudioFormat.CHANNEL_OUT_MONO
                    : AudioFormat.CHANNEL_OUT_STEREO;
            int minimum = AudioTrack.getMinBufferSize(
                sampleRate,
                mask,
                AudioFormat.ENCODING_PCM_16BIT
            );
            if (minimum <= 0) {
                throw new IllegalStateException("Unable to create audio buffer");
            }
            int bufferSize = Math.max(minimum, sampleRate * channels * 2 / 10);
            AudioTrack track = new AudioTrack.Builder()
                    .setAudioAttributes(new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build())
                    .setAudioFormat(new AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(mask)
                            .build())
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build();
            if (track.getState() != AudioTrack.STATE_INITIALIZED) {
                track.release();
                throw new IllegalStateException("Audio output is not initialized");
            }
            track.setVolume(1.0f);
            audioTrack = track;
            lastWriteResult = AudioTrack.ERROR_INVALID_OPERATION;
        }

        private File materializeSource(
                String source,
                Map<String, String> headers
        ) throws IOException {
            Uri uri = Uri.parse(source);
            if ("file".equalsIgnoreCase(uri.getScheme()) && uri.getPath() != null) {
                return new File(uri.getPath());
            }
            if (uri.getScheme() == null || uri.getScheme().isEmpty()) {
                File local = new File(source);
                if (local.isFile()) return local;
            }
            if (!"http".equalsIgnoreCase(uri.getScheme())
                    && !"https".equalsIgnoreCase(uri.getScheme())) {
                return null;
            }
            Context context = applicationContext;
            if (context == null) throw new IOException("Application context unavailable");
            HttpURLConnection connection = (HttpURLConnection) new URL(source).openConnection();
            connection.setInstanceFollowRedirects(true);
            connection.setConnectTimeout(30_000);
            connection.setReadTimeout(30_000);
            connection.setUseCaches(false);
            connection.setRequestProperty("Accept-Encoding", "identity");
            for (Map.Entry<String, String> entry : headers.entrySet()) {
                connection.setRequestProperty(entry.getKey(), entry.getValue());
            }
            File destination = new File(
                    context.getCacheDir(),
                    "omm-scratch-" + UUID.randomUUID() + ".media"
            );
            try {
                int status = connection.getResponseCode();
                if (status < 200 || status >= 300) {
                    throw new IOException("Audio download failed: HTTP " + status);
                }
                InputStream input = connection.getInputStream();
                try (InputStream stream = input;
                     FileOutputStream output = new FileOutputStream(destination)) {
                    byte[] buffer = new byte[16 * 1024];
                    int count;
                    while ((count = stream.read(buffer)) != -1) {
                        output.write(buffer, 0, count);
                    }
                }
                if (!destination.isFile() || destination.length() == 0) {
                    throw new IOException("Audio download returned an empty file");
                }
                preparedSourceFile = destination;
                return destination;
            } catch (Exception error) {
                deleteQuietly(destination);
                if (error instanceof IOException) throw (IOException) error;
                throw new IOException("Audio download failed", error);
            } finally {
                connection.disconnect();
            }
        }

        private void startRenderThreadLocked() {
            if (renderThread != null && renderThread.isAlive()) return;
            renderThread = new Thread(this::renderLoop, "omm-scratch-audio");
            renderThread.setPriority(Thread.MAX_PRIORITY);
            renderThread.start();
        }

        private void renderLoop() {
            byte[] output = new byte[0];
            while (true) {
                AudioTrack track = audioTrack;
                byte[] source = pcm;
                if (!playing || track == null || source == null) {
                    sleep(2);
                    continue;
                }
                int outputSize = CHUNK_FRAMES * channels * 2;
                if (output.length != outputSize) output = new byte[outputSize];
                try {
                    render(output, source);
                    int offset = 0;
                    int emptyWrites = 0;
                    while (offset < output.length && playing && track == audioTrack) {
                        int written = track.write(
                                output,
                                offset,
                                output.length - offset,
                                AudioTrack.WRITE_BLOCKING
                        );
                        lastWriteResult = written;
                        if (written == 0 && ++emptyWrites < 4) {
                            sleep(1);
                            continue;
                        }
                        if (written < 0 || written == 0) {
                            Log.e(TAG, "AudioTrack.write failed: " + written);
                            synchronized (lifecycleLock) {
                                if (track == audioTrack) playing = false;
                            }
                            break;
                        }
                        emptyWrites = 0;
                        offset += written;
                    }
                } catch (RuntimeException error) {
                    Log.e(TAG, "Scratch render loop failed", error);
                    synchronized (lifecycleLock) {
                        if (track == audioTrack) playing = false;
                    }
                    sleep(2);
                }
            }
        }

        private void render(byte[] target, byte[] source) {
            Arrays.fill(target, (byte) 0);
            ByteBuffer output = ByteBuffer.wrap(target).order(ByteOrder.LITTLE_ENDIAN);
            double frame = sourceFrame;
            float renderedRate = currentRate;
            float smoothing = (float) (1 - Math.exp(-1.0 / (sampleRate * 0.003)));
            for (int outputFrame = 0; outputFrame < CHUNK_FRAMES; outputFrame++) {
                float targetRate = rate;
                renderedRate += (targetRate - renderedRate) * smoothing;
                if (Math.abs(renderedRate) < 0.0001f) continue;
                if (frame < 0 || frame >= frameCount - 1) {
                    frame = clampFrame(frame);
                    if ((frame <= 0 && renderedRate < 0)
                            || (frame >= frameCount - 1 && renderedRate > 0)) {
                        continue;
                    }
                }
                int firstFrame = (int) Math.floor(frame);
                int nextFrame = Math.min(firstFrame + 1, frameCount - 1);
                double fraction = frame - firstFrame;
                int outputOffset = outputFrame * channels * 2;
                for (int channel = 0; channel < channels; channel++) {
                    short first = sample(source, firstFrame, channel);
                    short second = sample(source, nextFrame, channel);
                    int mixed = (int) Math.round(first + (second - first) * fraction);
                    output.putShort(outputOffset + channel * 2,
                            (short) Math.max(Short.MIN_VALUE,
                            Math.min(Short.MAX_VALUE, mixed)));
                }
                frame += renderedRate;
            }
            sourceFrame = clampFrame(frame);
            currentRate = renderedRate;
        }

        private short sample(byte[] source, int frame, int channel) {
            int offset = (frame * channels + channel) * 2;
            return (short) ((source[offset] & 0xff) | (source[offset + 1] << 8));
        }

        private DecodedPcm decode(File sourceFile)
                throws Exception {
            MediaExtractor extractor = new MediaExtractor();
            MediaCodec codec = null;
            try {
                if (sourceFile != null) {
                    extractor.setDataSource(sourceFile.getAbsolutePath());
                } else {
                    throw new IOException("Audio source is not a local file");
                }
                int trackIndex = -1;
                MediaFormat format = null;
                for (int index = 0; index < extractor.getTrackCount(); index++) {
                    MediaFormat candidate = extractor.getTrackFormat(index);
                    String mime = candidate.getString(MediaFormat.KEY_MIME);
                    if (mime != null && mime.startsWith("audio/")) {
                        trackIndex = index;
                        format = candidate;
                        break;
                    }
                }
                if (trackIndex < 0 || format == null) throw new IOException("No audio track");
                int decodedSampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                int decodedChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                if (decodedChannels < 1 || decodedChannels > 2) {
                    throw new IOException("Only mono and stereo audio are supported");
                }
                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime == null) throw new IOException("Missing audio MIME type");
                extractor.selectTrack(trackIndex);
                codec = MediaCodec.createDecoderByType(mime);
                codec.configure(format, null, null, 0);
                codec.start();

                ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
                boolean inputDone = false;
                boolean outputDone = false;
                int pcmEncoding = format.containsKey(MediaFormat.KEY_PCM_ENCODING)
                        ? format.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        : AudioFormat.ENCODING_PCM_16BIT;
                while (!outputDone) {
                    if (!inputDone) {
                        int inputIndex = codec.dequeueInputBuffer(10_000);
                        if (inputIndex >= 0) {
                            ByteBuffer input = codec.getInputBuffer(inputIndex);
                            if (input == null) throw new IOException("Decoder input unavailable");
                            int size = extractor.readSampleData(input, 0);
                            if (size < 0) {
                                codec.queueInputBuffer(inputIndex, 0, 0, 0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                                inputDone = true;
                            } else {
                                codec.queueInputBuffer(inputIndex, 0, size,
                                        extractor.getSampleTime(), 0);
                                extractor.advance();
                            }
                        }
                    }
                    int outputIndex = codec.dequeueOutputBuffer(info, 10_000);
                    if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        MediaFormat outputFormat = codec.getOutputFormat();
                        decodedSampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                        decodedChannels = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                        if (outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            pcmEncoding = outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING);
                        }
                    } else if (outputIndex >= 0) {
                        ByteBuffer output = codec.getOutputBuffer(outputIndex);
                        if (output != null && info.size > 0) {
                            if (info.offset < 0 || info.size < 0
                                    || info.offset > output.capacity()
                                    || info.size > output.capacity() - info.offset) {
                                throw new IOException("Invalid decoder output buffer");
                            }
                            output.position(info.offset);
                            output.limit(info.offset + info.size);
                            appendPcm16(bytes, output.slice(), pcmEncoding);
                        }
                        outputDone = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                        codec.releaseOutputBuffer(outputIndex, false);
                    }
                }
                byte[] pcm = bytes.toByteArray();
                int frames = pcm.length / (decodedChannels * 2);
                if (frames < 2) throw new IOException("Decoded audio is empty");
                return new DecodedPcm(pcm, decodedSampleRate, decodedChannels, frames);
            } finally {
                extractor.release();
                if (codec != null) {
                    try {
                        codec.stop();
                    } catch (Exception ignored) {
                    }
                    codec.release();
                }
            }
        }

        private void appendPcm16(
                ByteArrayOutputStream destination,
                ByteBuffer source,
                int encoding
        ) {
            source.order(ByteOrder.LITTLE_ENDIAN);
            if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                while (source.remaining() >= 4) {
                    float sample = Math.max(-1, Math.min(1, source.getFloat()));
                    int value = Math.round(sample * Short.MAX_VALUE);
                    destination.write(value & 0xff);
                    destination.write((value >> 8) & 0xff);
                }
                return;
            }
            if (encoding != AudioFormat.ENCODING_PCM_16BIT) {
                throw new IllegalArgumentException("Unsupported decoder PCM format: " + encoding);
            }
            byte[] chunk = new byte[source.remaining()];
            source.get(chunk);
            destination.write(chunk, 0, chunk.length);
        }

        private double clampFrame(double value) {
            if (frameCount <= 1) return 0;
            return Math.max(0, Math.min(frameCount - 1.0, value));
        }

        private void releaseTrackLocked() {
            playing = false;
            abandonAudioFocusLocked();
            if (audioTrack != null) {
                audioTrack.release();
                audioTrack = null;
            }
            lastWriteResult = AudioTrack.ERROR_INVALID_OPERATION;
        }

        private void requestAudioFocusLocked() {
            Context context = applicationContext;
            if (context == null) return;
            AudioManager manager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            if (manager == null) return;
            int result = manager.requestAudioFocus(
                    audioFocusChangeListener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN
            );
            audioFocusHeld = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
            if (!audioFocusHeld) {
                Log.w(TAG, "Audio focus request was not granted: " + result);
            }
        }

        private void abandonAudioFocusLocked() {
            if (!audioFocusHeld) return;
            Context context = applicationContext;
            if (context != null) {
                AudioManager manager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
                if (manager != null) {
                    manager.abandonAudioFocus(audioFocusChangeListener);
                }
            }
            audioFocusHeld = false;
        }

        private static void deleteQuietly(File file) {
            if (file == null) return;
            try {
                if (file.isFile()) file.delete();
            } catch (Exception ignored) {
            }
        }

        private static void sleep(long milliseconds) {
            try {
                Thread.sleep(milliseconds);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
            }
        }

        private static final class DecodedPcm {
            final byte[] bytes;
            final int sampleRate;
            final int channels;
            final int frameCount;

            DecodedPcm(byte[] bytes, int sampleRate, int channels, int frameCount) {
                this.bytes = bytes;
                this.sampleRate = sampleRate;
                this.channels = channels;
                this.frameCount = frameCount;
            }
        }
    }
}
