/// 返回媒体库和合集卡片共用的宽度。
///
/// 两个区块都使用双列卡片的视觉基准，横向滚动时也保持相同尺寸。
double collectionCardWidth(double availableWidth) {
  return ((availableWidth - 10) / 2).clamp(132.0, 180.0).toDouble();
}
