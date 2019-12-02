#!/usr/bin/env bash
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

TAG="${CIRRUS_TAG:-latest}"

sudo docker push "gcr.io/flutter-cirrus/build-flutter-image:$TAG"

