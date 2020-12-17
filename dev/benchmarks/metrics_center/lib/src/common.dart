// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:gcloud/db.dart';

// The official pub.dev/packages/gcloud documentation uses datastore_impl
// so we have to ignore implementation_imports here.
// ignore: implementation_imports
import 'package:gcloud/src/datastore_impl.dart';
import 'package:gcloud/storage.dart';

import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';

/// Common format of a metric data point.
class MetricPoint extends Equatable {
  MetricPoint(
    this.value,
    Map<String, String> tags,
  ) : _tags = SplayTreeMap<String, String>.from(tags);

  /// Can store integer values.
  final double value;

  /// Test name, unit, timestamp, configs, git revision, ..., in sorted order.
  UnmodifiableMapView<String, String> get tags =>
      UnmodifiableMapView<String, String>(_tags);

  /// Unique identifier for updating existing data point.
  ///
  /// We shouldn't have to worry about hash collisions until we have about
  /// 2^128 points.
  ///
  /// This id should stay constant even if the [tags.keys] are reordered.
  /// (Because we are using an ordered SplayTreeMap to generate the id.)
  String get id => sha256.convert(utf8.encode('$_tags')).toString();

  @override
  String toString() {
    return 'MetricPoint(value=$value, tags=$_tags)';
  }

  final SplayTreeMap<String, String> _tags;

  @override
  List<Object> get props => <Object>[value, tags];
}

/// Interface to write [MetricPoint].
abstract class MetricDestination {
  /// Insert new data points or modify old ones with matching id.
  Future<void> update(List<MetricPoint> points);
}

/// Create `AuthClient` in case we only have an access token without the full
/// credentials json. It's currently the case for Chrmoium LUCI bots.
AuthClient authClientFromAccessToken(String token, List<String> scopes) {
  final DateTime anHourLater = DateTime.now().add(const Duration(hours: 1));
  final AccessToken accessToken =
      AccessToken('Bearer', token, anHourLater.toUtc());
  final AccessCredentials accessCredentials =
      AccessCredentials(accessToken, null, scopes);
  return authenticatedClient(Client(), accessCredentials);
}

/// Get a Google Cloud Storage from a full credentials json (of a service
/// account).
Future<Storage> storageFromCredentialsJson(Map<String, dynamic> json) async {
  final AutoRefreshingAuthClient client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(json), Storage.SCOPES);
  return Storage(client, json[_kProjectId] as String);
}

/// Get a Google Cloud Storage from just an access token and its project id.
Storage storageFromAccessToken(String token, String projectId) {
  final AuthClient client = authClientFromAccessToken(token, Storage.SCOPES);
  return Storage(client, projectId);
}

// TODO(liyuqian): Remove `datastoreFromCredentialsJson` and
// `datastoreFromAccessToken` once the migration is fully done and we no longer
// need to fall back to the datastore.
Future<DatastoreDB> datastoreFromCredentialsJson(
    Map<String, dynamic> json) async {
  final AutoRefreshingAuthClient client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(json), DatastoreImpl.SCOPES);
  return DatastoreDB(DatastoreImpl(client, json[_kProjectId] as String));
}

DatastoreDB datastoreFromAccessToken(String token, String projectId) {
  final AuthClient client =
      authClientFromAccessToken(token, DatastoreImpl.SCOPES);
  return DatastoreDB(DatastoreImpl(client, projectId));
}

/// Some common tag keys
const String kGithubRepoKey = 'gitRepo';
const String kGitRevisionKey = 'gitRevision';
const String kUnitKey = 'unit';
const String kNameKey = 'name';
const String kSubResultKey = 'subResult';

/// Known github repo
const String kFlutterFrameworkRepo = 'flutter/flutter';
const String kFlutterEngineRepo = 'flutter/engine';

const String _kProjectId = 'project_id';
