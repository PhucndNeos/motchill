import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'dart:io' as io;

class MotchillNetworkImage extends StatelessWidget {
  const MotchillNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor = const Color(0xFF1C1B1B),
    this.placeholderIconColor = Colors.white24,
    this.errorIconColor = Colors.white38,
    this.iconSize = 42,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color placeholderColor;
  final Color placeholderIconColor;
  final Color errorIconColor;
  final double iconSize;

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (MotchillApiBase)',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  static final CacheManager _cacheManager = _MotchillImageCacheManager();

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _Placeholder(
        color: placeholderColor,
        icon: Icons.movie_outlined,
        iconColor: errorIconColor,
        iconSize: iconSize,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: _cacheManager,
      httpHeaders: _headers,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => _Placeholder(
        color: placeholderColor,
        icon: Icons.movie_outlined,
        iconColor: placeholderIconColor,
        iconSize: iconSize,
      ),
      errorWidget: (context, url, error) => _Placeholder(
        color: placeholderColor,
        icon: Icons.broken_image_outlined,
        iconColor: errorIconColor,
        iconSize: iconSize,
      ),
    );
  }
}

class _MotchillImageCacheManager extends CacheManager with ImageCacheManager {
  static const String _cacheKey = 'motchill_image_cache';
  static final _MotchillImageCacheManager _instance =
      _MotchillImageCacheManager._();

  factory _MotchillImageCacheManager() => _instance;

  _MotchillImageCacheManager._()
      : super(
          Config(
            _cacheKey,
            repo: JsonCacheInfoRepository(
              path: p.join(
                io.Directory.systemTemp.path,
                '$_cacheKey.json',
              ),
            ),
            fileSystem: _MotchillFileSystem(_cacheKey),
            stalePeriod: const Duration(days: 14),
            maxNrOfCacheObjects: 200,
          ),
        );
}

class _MotchillFileSystem implements FileSystem {
  _MotchillFileSystem(this.cacheKey) : _baseDir = _createDirectory(cacheKey);

  final String cacheKey;
  final Future<io.Directory> _baseDir;

  static Future<io.Directory> _createDirectory(String cacheKey) async {
    final directory = io.Directory(
      p.join(io.Directory.systemTemp.path, cacheKey),
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    final directory = await _baseDir;
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
    return const LocalFileSystem().file(p.join(directory.path, name));
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.iconSize,
  });

  final Color color;
  final IconData icon;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: iconColor,
        size: iconSize,
      ),
    );
  }
}
