import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

void main() {
  runApp(const MyApp());
}

// class Neighbor {
//   final String left;
//   final String right;
//   const Neighbor(this.left, this.right);
// }

class Possibilites {
  List<bool> storage;

  Possibilites(int count) : storage = List.filled(count, true);

  void ruleOut(int index) {
    storage[index] = false;
  }
}

class Wave {
  final List<List<Possibilites>> _possibleTiles;

  Wave.unobserved(int width, int height, TileStore tileStore)
      : _possibleTiles = List.generate(
          height,
          (int y) => List.generate(
            width,
            (int x) => Possibilites(tileStore.tileCount),
          ),
        );
}

class TileStore {
  String name;
  String tilesetsPath = p.join('..', 'WaveFunctionCollapse', 'tilesets');
  List<String> tileNames = [];
  List<ui.Image> tileImages = [];

  TileStore(this.name);

  int get tileCount => tileNames.length;

  Future<void> loadTiles() async {
    // ../WaveFunctionCollapse/tilesets/catalog.xml
    final path = p.join(tilesetsPath, '$name.xml');
    final content = File(path).readAsStringSync();
    final xml = XmlDocument.parse(content);
    for (var element in xml.findAllElements('tile')) {
      final name = element.getAttribute('name')!;
      tileNames.add(name);
      tileImages.add(await loadImage(name));
    }
    // for (var element in xml.findAllElements('neighor')) {
    //   final left = element.getAttribute('left')!;
    //   final right = element.getAttribute('right')!;
    // }
  }

  ui.Image getTileByIndex(int index) => tileImages[index];

  Future<ui.Image> loadImage(String tileName) async {
    // ../WaveFunctionCollapse/tilesets/catalog/tile.png
    final path = p.join(tilesetsPath, name, '$tileName.png');
    final bytes = File(path).readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}

class TileMap {
  final List<List<int>> _tiles;

  int get width => _tiles[0].length;
  int get height => _tiles.length;

  TileMap(int width, int height)
      : _tiles = List<List<int>>.generate(height, (int y) {
          return List<int>.filled(width, 0);
        });

  TileMap.fromTiles(this._tiles);

  factory TileMap.random(int width, int height, int tileCount) {
    return TileMap.fromTiles(List<List<int>>.generate(height, (int y) {
      return List<int>.generate(width, (int x) {
        return math.Random().nextInt(tileCount);
      });
    }));
  }

  int getTileIndex(int x, int y) => _tiles[y][x];
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late TileStore tileStore;
  TileMap? tileMap;

  @override
  void initState() {
    tileStore = TileStore('Circuit');
    tileStore.loadTiles().then((value) {
      if (mounted) {
        setState(() {
          tileMap = TileMap.random(10, 10, tileStore.tileCount);
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Material(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: tileMap != null
                ? CustomPaint(
                    painter: TilePainter(
                      tileStore: tileStore,
                      tileMap: tileMap!,
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class TilePainter extends CustomPainter {
  final TileStore tileStore;
  final TileMap tileMap;

  TilePainter({required this.tileMap, required this.tileStore});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final tileWidth = size.width / tileMap.width;
    final tileHeight = size.width / tileMap.width;
    for (int x = 0; x < tileMap.width; x++) {
      for (int y = 0; y < tileMap.height; y++) {
        final index = tileMap.getTileIndex(x, y);
        final tile = tileStore.getTileByIndex(index);
        final rect = Rect.fromLTWH(
          x * tileWidth,
          y * tileHeight,
          tileWidth,
          tileHeight,
        );
        canvas.drawImageRect(
          tile,
          Rect.fromLTWH(0, 0, tile.width.toDouble(), tile.height.toDouble()),
          rect,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
