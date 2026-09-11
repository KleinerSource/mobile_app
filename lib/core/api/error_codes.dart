/// 客户端生成的错误码。
///
/// 服务端返回的 `message` / `error` 不经过这里转换，仍由调用方原样展示；
/// 只有客户端自己无法从服务端取得可展示信息时，才使用这些错误码做本地化。
abstract final class AppErrorCode {
  static const operationFailed = 'error.operation_failed';
  static const responseFormatInvalid = 'error.response_format_invalid';
  static const responseDataMissing = 'error.response_data_missing';
  static const requestTimeout = 'error.request_timeout';
  static const networkUnavailable = 'error.network_unavailable';
  static const routeNotFound = 'error.route_not_found';
  static const validationFailed = 'error.validation_failed';
  static const httpError = 'error.http_error';
  static const authenticationRequired = 'error.authentication_required';
  static const fileTransferCanceled = 'canceled';
  static const fileSourceNotFound = 'error.file_source_not_found';
  static const fileTransferFailed = 'error.file_transfer_failed';
  static const fileTargetExists = 'already_exists';
  static const fileRangeUnsupported = 'error.file_range_unsupported';
  static const updateFailed = 'error.update_failed';
  static const connectionClosed = 'error.connection_closed';
  static const serverCompatibility = 'error.server_compatibility';
  static const mediaSourceReferenceInvalid =
      'error.media_source_reference_invalid';
  static const mediaLibraryNotFound = 'error.media_library_not_found';
  static const feiniuRequestFailed = 'error.feiniu_request_failed';
  static const stashApiKeyInvalid = 'error.stash_api_key_invalid';
  static const stashRequestFailed = 'error.stash_request_failed';
  static const stashGraphqlFailed = 'error.stash_graphql_failed';
  static const unsupportedSourceCapability =
      'error.unsupported_source_capability';

  static const previewSegmentsInvalid = 'error.preview_segments_invalid';
  static const previewSegmentDurationInvalid =
      'error.preview_segment_duration_invalid';
  static const previewExcludeInvalid = 'error.preview_exclude_invalid';
  static const previewPresetInvalid = 'error.preview_preset_invalid';
  static const previewSpriteIntervalInvalid =
      'error.preview_sprite_interval_invalid';
  static const previewSpriteMinimumInvalid =
      'error.preview_sprite_minimum_invalid';
  static const previewSpriteMaximumInvalid =
      'error.preview_sprite_maximum_invalid';
  static const previewSpriteSizeInvalid =
      'error.preview_sprite_size_invalid';

  static const ommRequestFailed = 'error.omm_request_failed';
  static const ommTranscodeStatusFailed = 'error.omm_transcode_status_failed';
  static const ommSubtitleInvalid = 'error.omm_subtitle_invalid';
  static const ommSubtitleFetchFailed = 'error.omm_subtitle_fetch_failed';
  static const ommResponseInvalid = 'error.omm_response_invalid';
  static const ommLibraryResponseInvalid = 'error.omm_library_response_invalid';
  static const ommFolderResponseInvalid = 'error.omm_folder_response_invalid';
  static const ommPathValidationResponseInvalid =
      'error.omm_path_validation_response_invalid';
  static const ommScanTaskIdMissing = 'error.omm_scan_task_id_missing';
  static const ommBatchScanResponseInvalid =
      'error.omm_batch_scan_response_invalid';
  static const ommLibraryIdMissing = 'error.omm_library_id_missing';
  static const ommFolderIdMissing = 'error.omm_folder_id_missing';
  static const ommSourceIdInvalid = 'error.omm_source_id_invalid';
  static const ommIdInvalid = 'error.omm_id_invalid';
  static const unsupportedResourceType = 'error.unsupported_resource_type';

  static const taskResponseInvalid = 'error.task_response_invalid';
  static const taskIdMissing = 'error.task_id_missing';
  static const previewTaskIdRequired = 'error.preview_task_id_required';
  static const actorMappingLoadFailed = 'error.actor_mapping_load_failed';
  static const previewTaskCreateFailed = 'error.preview_task_create_failed';
  static const previewTaskStatusInvalid = 'error.preview_task_status_invalid';
  static const avatarContentEmpty = 'error.avatar_content_empty';
}
