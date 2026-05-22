import 'package:flutter/material.dart';

import '../../../core/models/movie.dart';

class MovieDetailContent extends StatelessWidget {
  const MovieDetailContent({super.key, required this.movie});
  final MovieDetail movie;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(movie.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (movie.plot != null) Text(movie.plot!),
      ],
    );
  }
}
