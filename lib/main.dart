import 'package:flutter/material.dart';
import 'dart:math';
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
  late Set<OrientedTile> possibleTiles;

  Possibilites(int tileCount) {
    for (int i = 0; i < tileCount; i++) {
      for (final orientation in Orientation.values) {
        possibleTiles.add(OrientedTile(i, orientation));
      }
    }
  }

  bool get isImpossible => possibleTiles.isEmpty;
  bool get isResolved => possibleTiles.length == 1;

  OrientedTile get resovledTile {
    assert(isResolved);
    return possibleTiles.first;
  }

  void ruleOut(OrientedTile tile) {
    possibleTiles.remove(tile);
  }

  void resolveTo(OrientedTile tile) {
    assert(possibleTiles.contains(tile));
    possibleTiles.clear();
    possibleTiles.add(tile);
  }

  OrientedTile getRandom(Random random) {
    assert(!isImpossible);
    final index = random.nextInt(possibleTiles.length);
    return possibleTiles.elementAt(index);
  }
}

class Location {
  final int x;
  final int y;
  const Location(this.x, this.y);

  @override
  bool operator ==(other) => other is Location && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x.hashCode, y.hashCode);
}

class Wave {
  final List<List<Possibilites>> _possibleTiles;
  final Random _random = Random();

  Wave.unobserved(int width, int height, TileStore tileStore)
      : _possibleTiles = List.generate(
          height,
          (int y) => List.generate(
            width,
            (int x) =>
                Possibilites(tileStore.tileCount * Orientation.values.length),
          ),
        );

  int get width => _possibleTiles[0].length;
  int get height => _possibleTiles.length;

  Possibilites getAt(Location location) {
    return _possibleTiles[location.y][location.x];
  }

  void constrainNeighbors(Location location) {}

  Location? getMaximalityConstrainedPosition() {}

  TileMap collapse() {
    // Pick a random tile and collapse it.
    var target = getMaximalityConstrainedPosition();
    while (target != null) {
      final possibilites = getAt(target);
      final actualTile = possibilites.getRandom(_random);
      possibilites.resolveTo(actualTile);
      constrainNeighbors(target);
      // Then, while we still have tiles to collapse, pick a maximally
      // constrainted location, and collapse.
      target = getMaximalityConstrainedPosition();
      // If the location has no possibilities, give up?
      if (target != null && getAt(target).isImpossible) {
        throw "fail";
      }
      // Repeat until we have no more tiles to collapse.
    }
    return TileMap.fromTiles(_possibleTiles
        .map((row) => row.map((p) => p.resovledTile).toList())
        .toList());
  }
}

enum Orientation {
  rotated0,
  rotated90,
  rotated180,
  rotated270,
  reflected0,
  reflected90,
  reflected180,
  reflected270,
}

class OrientedTile {
  final int id;
  final Orientation orientation;

  OrientedTile(this.id, this.orientation);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrientedTile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orientation == other.orientation;

  @override
  int get hashCode => Object.hash(id, orientation);
}

class NeighborOracle {
  bool canBeAdjacent(OrientedTile left, OrientedTile right) {
    return true;
  }
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
    // for (var element in xml.findAllElements('neighbor')) {
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
  final List<List<OrientedTile>> _tiles;

  int get width => _tiles[0].length;
  int get height => _tiles.length;

  TileMap(int width, int height)
      : _tiles = List<List<OrientedTile>>.generate(height, (int y) {
          return List<OrientedTile>.filled(
              width, OrientedTile(0, Orientation.rotated0));
        });

  TileMap.fromTiles(this._tiles);

  factory TileMap.random(int width, int height, int tileCount) {
    return TileMap.fromTiles(List<List<OrientedTile>>.generate(height, (int y) {
      return List<OrientedTile>.generate(width, (int x) {
        return OrientedTile(
          Random().nextInt(tileCount),
          Orientation.values[Random().nextInt(Orientation.values.length)],
        );
      });
    }));
  }

  OrientedTile getTileIndex(int x, int y) => _tiles[y][x];
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

  void applyTransform(Canvas canvas, Orientation orientation) {
    switch (orientation) {
      case Orientation.rotated0:
        break;
      case Orientation.rotated90:
        canvas.rotate(pi / 2);
        break;
      case Orientation.rotated180:
        canvas.rotate(pi);
        break;
      case Orientation.rotated270:
        canvas.rotate(-pi / 2);
        break;
      case Orientation.reflected0:
        canvas.scale(-1, 1);
        break;
      case Orientation.reflected90:
        canvas.rotate(pi / 2);
        canvas.scale(-1, 1);
        break;
      case Orientation.reflected180:
        canvas.rotate(pi);
        canvas.scale(-1, 1);
        break;
      case Orientation.reflected270:
        canvas.rotate(-pi / 2);
        canvas.scale(-1, 1);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final tileWidth = size.width / tileMap.width;
    final tileHeight = size.width / tileMap.width;
    for (int x = 0; x < tileMap.width; x++) {
      for (int y = 0; y < tileMap.height; y++) {
        final orientedTile = tileMap.getTileIndex(x, y);
        final tile = tileStore.getTileByIndex(orientedTile.id);
        final rect = Rect.fromLTWH(0, 0, tileWidth, tileHeight);
        canvas.save();
        canvas.translate((x + 0.5) * tileWidth, (y + 0.5) * tileHeight);
        applyTransform(canvas, orientedTile.orientation);
        canvas.translate(-0.5 * tileWidth, -0.5 * tileHeight);
        canvas.drawImageRect(
          tile,
          Rect.fromLTWH(0, 0, tile.width.toDouble(), tile.height.toDouble()),
          rect,
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
