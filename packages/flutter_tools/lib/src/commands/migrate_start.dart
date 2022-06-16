// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:process/process.dart';

import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../migrate/migrate_compute.dart';
import '../migrate/migrate_result.dart';
import '../migrate/migrate_utils.dart';
import '../project.dart';
import '../runner/flutter_command.dart';
import 'migrate.dart';

class MigrateStartCommand extends FlutterCommand {
  MigrateStartCommand({
    bool verbose = false,
    required this.logger,
    required this.fileSystem,
    required Platform platform,
    required ProcessManager processManager,
  }) : _verbose = verbose,
       migrateUtils = MigrateUtils(
         logger: logger,
         fileSystem: fileSystem,
         platform: platform,
         processManager: processManager,
       ) {
    requiresPubspecYaml();
    argParser.addOption(
      'staging-directory',
      help: 'Specifies the custom migration staging directory used to stage and edit proposed changes. '
            'This path can be absolute or relative to the flutter project root.',
      valueHelp: 'path',
    );
    argParser.addOption(
      'project-directory',
      help: 'The root directory of the flutter project.',
      valueHelp: 'path',
    );
    argParser.addOption(
      'platforms',
      help: 'Restrict the tool to only migrating the listed platforms. By default all platforms generated by '
            'flutter create will be migrated. To indicate the project root, use the `root` platform',
      valueHelp: 'root,android,ios,windows...',
    );
    argParser.addFlag(
      'delete-temp-directories',
      help: 'Indicates if the temporary directories created by the migrate tool be deleted.',
    );
    argParser.addOption(
      'base-app-directory',
      help: 'The directory containing the base reference app. This is used as the common ancestor in a 3 way merge. '
            'Providing this directory will prevent the tool from generating its own. This is primarily used '
            'in testing and CI.',
      valueHelp: 'path',
    );
    argParser.addOption(
      'target-app-directory',
      help: 'The directory containing the target reference app. This is used as the target app in 3 way merge. '
            'Providing this directory will prevent the tool from generating its own. This is primarily used '
            'in testing and CI.',
      valueHelp: 'path',
    );
    argParser.addFlag(
      'allow-fallback-base-revision',
      help: 'If a base revision cannot be determined, this flag enables using flutter 1.0.0 as a fallback base revision. '
            'Using this fallback will typically produce worse quality migrations and possibly more conflicts.',
    );
    argParser.addOption(
      'base-revision',
      help: 'Manually sets the base revision to generate the base ancestor reference app with. This may be used '
            'if the tool is unable to determine an appropriate base revision.',
      valueHelp: 'git revision hash',
    );
    argParser.addOption(
      'target-revision',
      help: 'Manually sets the target revision to generate the target reference app with. Passing this indicates '
            'that the current flutter sdk version is not the version that should be migrated to.',
      valueHelp: 'git revision hash',
    );
    argParser.addFlag(
      'prefer-two-way-merge',
      negatable: false,
      help: 'Avoid three way merges when possible. Enabling this effectively ignores the base ancestor reference '
            'files when a merge is required, opting for a simpler two way merge instead. In some edge cases typically '
            'involving using a fallback or incorrect base revision, the default three way merge algorithm may produce '
            'incorrect merges. Two way merges are more conflict prone, but less likely to produce incorrect results '
            'silently.',
    );
  }

  final bool _verbose;

  final Logger logger;

  final FileSystem fileSystem;

  final MigrateUtils migrateUtils;

  @override
  final String name = 'start';

  @override
  final String description = r'Begins a new migration. Computes the changes needed to migrate the project from the base revision of Flutter to the current revision of Flutter and outputs the results in a working directory. Use `$ flutter migrate apply` accept and apply the changes.';

  @override
  String get category => FlutterCommandCategory.project;

  @override
  Future<Set<DevelopmentArtifact>> get requiredArtifacts async => const <DevelopmentArtifact>{};

  @override
  Future<FlutterCommandResult> runCommand() async {
    final String? projectDirectory = stringArg('project-directory');
    final FlutterProjectFactory flutterProjectFactory = FlutterProjectFactory(logger: logger, fileSystem: fileSystem);
    final FlutterProject project = projectDirectory == null
      ? FlutterProject.current()
      : flutterProjectFactory.fromDirectory(fileSystem.directory(projectDirectory));
    if (project.isModule || project.isPlugin) {
      logger.printError('Migrate tool only supports app projects. This project is a ${project.isModule ? 'module' : 'plugin'}');
      return const FlutterCommandResult(ExitStatus.fail);
    }

    if (!await gitRepoExists(project.directory.path, logger, migrateUtils)) {
      return const FlutterCommandResult(ExitStatus.fail);
    }

    Directory stagingDirectory = project.directory.childDirectory(kDefaultMigrateStagingDirectoryName);
    final String? customStagingDirectoryPath = stringArg('staging-directory');
    if (customStagingDirectoryPath != null) {
      if (fileSystem.path.isAbsolute(customStagingDirectoryPath)) {
        stagingDirectory = fileSystem.directory(customStagingDirectoryPath);
      } else {
        stagingDirectory = project.directory.childDirectory(customStagingDirectoryPath);
      }
    }
    if (stagingDirectory.existsSync()) {
      logger.printStatus('Old migration already in progress.', emphasis: true);
      logger.printStatus('Pending migration files exist in `${stagingDirectory.path}/$kDefaultMigrateStagingDirectoryName`');
      logger.printStatus('Resolve merge conflicts and accept changes with by running:');
      printCommandText('flutter migrate apply', logger);
      logger.printStatus('You may also abandon the existing migration and start a new one with:');
      printCommandText('flutter migrate abandon', logger);
      return const FlutterCommandResult(ExitStatus.fail);
    }

    if (await hasUncommittedChanges(project.directory.path, logger, migrateUtils)) {
      return const FlutterCommandResult(ExitStatus.fail);
    }

    List<SupportedPlatform>? platforms;
    if (stringArg('platforms') != null) {
      platforms = <SupportedPlatform>[];
      for (String platformString in stringArg('platforms')!.split(',')) {
        platformString = platformString.trim();
        platforms.add(SupportedPlatform.values.firstWhere(
          (SupportedPlatform val) => val.toString() == 'SupportedPlatform.$platformString'
        ));
      }
    }

    final MigrateResult? migrateResult = await computeMigration(
      verbose: _verbose,
      flutterProject: project,
      baseAppPath: stringArg('base-app-directory'),
      targetAppPath: stringArg('target-app-directory'),
      baseRevision: stringArg('base-revision'),
      targetRevision: stringArg('target-revision'),
      deleteTempDirectories: boolArg('delete-temp-directories'),
      platforms: platforms,
      preferTwoWayMerge: boolArg('prefer-two-way-merge'),
      allowFallbackBaseRevision: boolArg('allow-fallback-base-revision'),
      fileSystem: fileSystem,
      logger: logger,
      migrateUtils: migrateUtils,
    );
    if (migrateResult == null) {
      return const FlutterCommandResult(ExitStatus.fail);
    }

    _deleteTempDirectories(
      paths: <String>[],
      directories: migrateResult.tempDirectories,
    );

    await writeStagingDir(migrateResult, logger, verbose: _verbose, flutterProject: project);

    logger.printStatus('The migrate tool has staged proposed changes in the migrate working directory.\n');
    logger.printStatus('Guided conflict resolution wizard:');
    printCommandText('flutter migrate resolve-conflicts', logger);
    logger.printStatus('Check the status and diffs of the migration with:');
    printCommandText('flutter migrate status', logger);
    logger.printStatus('Abandon the proposed migration with:');
    printCommandText('flutter migrate abandon', logger);
    logger.printStatus('Accept staged changes after resolving any merge conflicts with:');
    printCommandText('flutter migrate apply', logger);

    return const FlutterCommandResult(ExitStatus.success);
  }

  /// Deletes the files or directories at the provided paths.
  void _deleteTempDirectories({List<String> paths = const <String>[], List<Directory> directories = const <Directory>[]}) {
    for (final Directory d in directories) {
      try {
        d.deleteSync(recursive: true);
      } on FileSystemException catch (e) {
        logger.printError('Unabled to delete ${d.path} due to ${e.message}, please clean up manually.');
      }
    }
    for (final String p in paths) {
      try {
        fileSystem.directory(p).deleteSync(recursive: true);
      } on FileSystemException catch (e) {
        logger.printError('Unabled to delete ${d.path} due to ${e.message}, please clean up manually.');
      }
    }
  }
}
