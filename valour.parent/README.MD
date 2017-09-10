# Valour

## Introduction

## Updating Valour's versions
Valour is stradling upon three build systems - the OSGi for generating the Eclipse Update site for the Eclipse Valour plugin, Gradle for generating the IntelliJ Valour plugin and Maven for generating artefacts to be using in Maven builds to compile Valour and generate the necessary monitoring system. This section describes how to update the versions for the three build systems.

For releases:
1. Use the tycho-versions plugin to update the OSGi and Maven versions e.g. ```mvn tycho-versions:set-version -DnewVersion=1.0.0```.
1. Update the Gradle version in the top level build.gradle file accordingly.

For snapshots:
1. Use the tycho-versions plugin to update the OSGi and Maven versions e.g. ```mvn tycho-versions:set-version -DnewVersion=1.0.1.qualifier``` This will set the OSGi versions to 1.0.1.qualifier, while the Maven versions will be updated to 1.0.1-SNAPSHOT.
1. Update the Gradle version in the top level build.gradle file accordingly.