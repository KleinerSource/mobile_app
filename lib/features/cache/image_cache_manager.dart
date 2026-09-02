import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 应用图片专用 CacheManager。
///
/// 与 [DefaultCacheManager] 共用同一份缓存目录和索引（key 相同，设置页的
/// 统计与清空因此继续生效），仅把对象上限从默认的 200 放大：带
/// `maxWidthDiskCache` 的图片每张会写两条缓存（原图 + resized），200 条
/// 上限实际只够缓存约一百张封面，媒体库一次浏览就会触发容量清洗，把
/// 首页和网格的封面条目整批删光，下次启动全部重新下载（表现为封面逐个
/// 占位加载）。所有 [CachedNetworkImage] 必须统一传本实例——库里只要还
/// 有 DefaultCacheManager 实例在跑，它仍会按 200 的上限清洗这份共享索引。
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  AppImageCacheManager._()
    : super(Config(DefaultCacheManager.key, maxNrOfCacheObjects: 3000));

  static final AppImageCacheManager instance = AppImageCacheManager._();
}
