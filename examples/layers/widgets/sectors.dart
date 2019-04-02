// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../rendering/src/sector_layout.dart';

RenderBox initCircle() {
  return RenderBoxToRenderSectorAdapter(
    innerRadius: 25.0,
    child: RenderSectorRing(padding: 0.0),
  );
}

class SectorApp extends StatefulWidget {
  @override
  SectorAppState createState() => SectorAppState();
}

class SectorAppState extends State<SectorApp> {
  final RenderBoxToRenderSectorAdapter sectors = initCircle();
  final math.Random rand = math.Random(1);

  List<double> wantedSectorSizes = <double>[];
  List<double> actualSectorSizes = <double>[];
  double get currentTheta => wantedSectorSizes.fold<double>(0.0, (double total, double value) => total + value);

  void addSector() {
    final double currentTheta = this.currentTheta;
    if (currentTheta < kTwoPi) {
      double deltaTheta;
      if (currentTheta >= kTwoPi - (math.pi * 0.2 + 0.05))
        deltaTheta = kTwoPi - currentTheta;
      else
        deltaTheta = math.pi * rand.nextDouble() / 5.0 + 0.05;
      wantedSectorSizes.add(deltaTheta);
      updateEnabledState();
    }
  }

  void removeSector() {
    if (wantedSectorSizes.isNotEmpty) {
      wantedSectorSizes.removeLast();
      updateEnabledState();
    }
  }

  void doUpdates() {
    int index = 0;
    while (index < actualSectorSizes.length &&
        index < wantedSectorSizes.length &&
        actualSectorSizes[index] == wantedSectorSizes[index])
      index += 1;
    final RenderSectorRing ring = sectors.child;
    while (index < actualSectorSizes.length) {
      ring.remove(ring.lastChild);
      actualSectorSizes.removeLast();
    }
    while (index < wantedSectorSizes.length) {
      final Color color = Color(((0xFF << 24) + rand.nextInt(0xFFFFFF)) | 0x808080);
      ring.add(RenderSolidColor(color, desiredDeltaTheta: wantedSectorSizes[index]));
      actualSectorSizes.add(wantedSectorSizes[index]);
      index += 1;
    }
  }

  static RenderBox initSector(Color color) {
    final RenderSectorRing ring = RenderSectorRing(padding: 1.0);
    ring.add(RenderSolidColor(const Color(0xFF909090), desiredDeltaTheta: kTwoPi * 0.15));
    ring.add(RenderSolidColor(const Color(0xFF909090), desiredDeltaTheta: kTwoPi * 0.15));
    ring.add(RenderSolidColor(color, desiredDeltaTheta: kTwoPi * 0.2));
    return RenderBoxToRenderSectorAdapter(
      innerRadius: 5.0,
      child: ring,
    );
  }

  RenderBoxToRenderSectorAdapter sectorAddIcon = initSector(const Color(0xFF00DD00));
  RenderBoxToRenderSectorAdapter sectorRemoveIcon = initSector(const Color(0xFFDD0000));

  bool _enabledAdd = true;
  bool _enabledRemove = false;
  void updateEnabledState() {
    setState(() {
      _enabledAdd = currentTheta < kTwoPi;
      _enabledRemove = wantedSectorSizes.isNotEmpty;
    });
  }

  Widget buildBody() {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 25.0),
          child: Row(
            children: <Widget>[
              RaisedButton(
                onPressed: _enabledAdd ? addSector : null,
                child: IntrinsicWidth(
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(4.0),
                        margin: const EdgeInsets.only(right: 10.0),
                        child: WidgetToRenderBoxAdapter(renderBox: sectorAddIcon),
                      ),
                      const Text('ADD SECTOR'),
                    ],
                  ),
                ),
              ),
              RaisedButton(
                onPressed: _enabledRemove ? removeSector : null,
                child: IntrinsicWidth(
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(4.0),
                        margin: const EdgeInsets.only(right: 10.0),
                        child: WidgetToRenderBoxAdapter(renderBox: sectorRemoveIcon),
                      ),
                      const Text('REMOVE SECTOR'),
                    ],
                  ),
                ),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceAround,
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(),
            ),
            padding: const EdgeInsets.all(8.0),
            child: WidgetToRenderBoxAdapter(
              renderBox: sectors,
              onBuild: doUpdates,
            ),
          ),
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      title: 'Sector Layout',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Sector Layout in a Widget Tree'),
        ),
        body: buildBody(),
      ),
    );
  }
}

void main() { runApp(SectorApp()); }
