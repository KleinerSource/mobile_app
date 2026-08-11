const taxonomyLocalLimit = 300;

bool shouldUseLocalTaxonomySearch({
  required bool hasMore,
  required int itemCount,
}) {
  return !hasMore && itemCount <= taxonomyLocalLimit;
}
