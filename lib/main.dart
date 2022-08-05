import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

void main() {
  runApp(const MyApp());
}

class AllowedAdjacency {
  final OrientedTile left;
  final OrientedTile right;
  const AllowedAdjacency(this.left, this.right);
}

class Possibilites {
  late Set<OrientedTile> possibleTiles;

  Possibilites(int tileCount) {
    for (int i = 0; i < tileCount; i++) {
      for (final orientation in Orientation.values) {
        possibleTiles.add(OrientedTile(i, orientation));
      }
    }
  }

  int get count => possibleTiles.length;

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

  bool isValidNeighborTile(
    NeighborOracle oracle,
    Relationship relationship,
    OrientedTile neighborTile,
  ) {
    for (final tile in possibleTiles) {
      if (relationship.isHorizontal) {
        if (oracle.isValidLeftRight(relationship.left(tile, neighborTile),
            relationship.right(tile, neighborTile))) {
          return true;
        }
      } else if (relationship.isVertical) {
        if (oracle.isValidTopBottom(relationship.top(tile, neighborTile),
            relationship.bottom(tile, neighborTile))) {
          return true;
        }
      }
    }
    return false;
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

class Relationship {
  final Location first;
  final Location second;
  const Relationship(this.first, this.second);

  int get dx => first.x - second.x;
  int get dy => first.y - second.y;

  bool get isHorizontal => dy == 0;
  bool get isVertical => dx == 0;

  T left<T>(T firstData, T secondData) {
    assert(isHorizontal);
    return dx > 0 ? firstData : secondData;
  }

  T right<T>(T firstData, T secondData) {
    assert(isHorizontal);
    return dx > 0 ? secondData : firstData;
  }

  T top<T>(T firstData, T secondData) {
    assert(isVertical);
    return dy > 0 ? firstData : secondData;
  }

  T bottom<T>(T firstData, T secondData) {
    assert(isVertical);
    return dy > 0 ? secondData : firstData;
  }
}

class Wave {
  final List<List<Possibilites>> _possibleTiles;
  final Random _random = Random();
  final NeighborOracle _neighborOracle = NeighborOracle();

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

  Iterable<Location> getNeighbors(Location location) sync* {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 || dy == 0) {
          continue;
        }
        final x = location.x + dx;
        final y = location.y + dy;
        if (x >= 0 && x < width && y >= 0 && y < height) {
          yield Location(x, y);
        }
      }
    }
  }

  Iterable<Location> getUnresolvedNeighbors(Location location) sync* {
    for (final neighbor in getNeighbors(location)) {
      if (!getAt(neighbor).isResolved) {
        yield neighbor;
      }
    }
  }

  void constrainNeighbors(Location location) {
    Set<Location> modified = {};
    modified.add(location);
    while (modified.isNotEmpty) {
      final location = modified.first;
      modified.remove(location);
      final possibilities = getAt(location);

      // We changed, let all of our neighbors know so that they can confirm
      // their possibilities are still valid.
      for (final neighbor in getNeighbors(location)) {
        final relationship = Relationship(location, neighbor);
        final neighborPossibilities = getAt(neighbor);
        for (final neighborTile in neighborPossibilities.possibleTiles) {
          if (!possibilities.isValidNeighborTile(
              _neighborOracle, relationship, neighborTile)) {
            neighborPossibilities.ruleOut(neighborTile);
            modified.add(neighbor);
          }
        }
      }
    }
  }

  Location? getMaximalityConstrainedPosition() {
    List<Location> bestLocations = [];
    int? bestCount;
    for (int y = 0; y < height; ++y) {
      for (int x = 0; x < width; ++x) {
        var possibilites = getAt(Location(x, y));
        if (bestLocations.isEmpty) {
          bestLocations.add(Location(x, y));
          bestCount = possibilites.count;
        } else if (possibilites.count == bestCount) {
          bestLocations.add(Location(x, y));
        } else if (possibilites.count < bestCount!) {
          bestLocations = [Location(x, y)];
          bestCount = possibilites.count;
        }
      }
    }
    if (bestLocations.isEmpty) {
      return null;
    }
    return bestLocations.elementAt(_random.nextInt(bestLocations.length));
  }

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
  final List<AllowedAdjacency> _adjacencies = [];

  void addValidLeftRight(OrientedTile left, OrientedTile right) {
    _adjacencies.add(AllowedAdjacency(left, right, true));
  }

  bool isValidLeftRight(OrientedTile left, OrientedTile right) {
    // Convert this into a left/right problem?
    // validate against known allowed relationships.
    return true;
  }

  bool isValidTopBottom(OrientedTile top, OrientedTile bottom) {
    // Rotate both tiles to their left-right forms and check?
    return false;
  }
}

class TileStore {
  String name;
  String tilesetsPath = p.join('..', 'WaveFunctionCollapse', 'tilesets');
  List<String> tileNames = [];
  List<ui.Image> tileImages = [];

  TileStore(this.name);

  int get tileCount => tileNames.length;

  int getTileIdByName(String name) => tileNames.indexOf(name);

  OrientedTile orientedTileByName(String descriptor) {
    List<String> parts = descriptor.split(' ');
    if (parts.length == 1) {
      return OrientedTile(getTileIdByName(parts[0]), Orientation.rotated0);
    }
    if (parts.length == 2) {
      final name = parts[0];
      final orientationIndex = int.parse(parts[1]);
      return OrientedTile(
          getTileIdByName(name), Orientation.values[orientationIndex]);
    }
    throw "invalid tile descriptor";
  }

  Future<void> loadTiles() async {
    // ../WaveFunctionCollapse/tilesets/catalog.xml
    final path = p.join(tilesetsPath, '$name.xml');
    final content = File(path).readAsStringSync();
    final xml = XmlDocument.parse(content);
    for (var element in xml.findAllElements('tile')) {
      final name = element.getAttribute('name')!;
      tileNames.add(name);
      tileImages.add(await loadImage(name));
      // TODO: Record symmetries.
    }
    final oracle = NeighborOracle();
    // 		<neighbor left="bridge" right="bridge"/>
    // 		<neighbor left="bridge 1" right="bridge 1"/>
    // 		<neighbor left="bridge 1" right="connection 1"/>
    // 		<neighbor left="bridge 1" right="t 2"/>
    // 		<neighbor left="bridge 1" right="t 3"/>
    // 		<neighbor left="bridge 1" right="track 1"/>
    for (var element in xml.findAllElements('neighbor')) {
      final leftTile = orientedTileByName(element.getAttribute('left')!);
      final rightTile = orientedTileByName(element.getAttribute('right')!);
      oracle.addValidLeftRight(leftTile, rightTile);
    }
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
