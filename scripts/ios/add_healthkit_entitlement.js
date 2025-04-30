#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');
const plist = require('plist');
const xcode = require('xcode'); // Requires `npm install xcode` or adding to devDependencies

module.exports = function(context) {
    console.log('Executing add_healthkit_entitlement.js hook...');

    const projectRoot = context.opts.projectRoot;
    const platformPath = path.join(projectRoot, 'platforms', 'ios');
    const healthKitEntitlement = 'com.apple.developer.healthkit';
    const healthKitEntitlementValue = true;

    // --- Find Project Name ---
    let projectName = null;
    const configXmlPath = path.join(projectRoot, 'config.xml');
    if (fs.existsSync(configXmlPath)) {
        try {
            const configXmlContent = fs.readFileSync(configXmlPath, 'utf-8');
            const nameMatch = configXmlContent.match(/<name>(.*?)<\/name>/);
            if (nameMatch && nameMatch[1]) {
                projectName = nameMatch[1].trim();
            }
        } catch (e) {
            console.warn('Could not read project name from config.xml:', e);
        }
    }

    if (!projectName) {
        const platformContents = fs.readdirSync(platformPath);
        projectName = platformContents.find(item => item.endsWith('.xcodeproj'))?.replace('.xcodeproj', '');
    }

    if (!projectName) {
        console.error('Error: Could not determine project name.');
        return;
    }
    console.log(`Determined project name: ${projectName}`);

    // --- Modify Entitlements File ---
    const entitlementsFileName = `${projectName}.entitlements`;
    // Relative path from platformPath/ProjectName used in build settings
    const entitlementsRelativePath = path.join(projectName, entitlementsFileName);
    // Full path for reading/writing
    const entitlementsFilePath = path.join(platformPath, projectName, entitlementsFileName);

    console.log(`Target entitlements file path: ${entitlementsFilePath}`);
    console.log(`Target entitlements relative path for build setting: ${entitlementsRelativePath}`);

    let entitlementsData = {};
    if (fs.existsSync(entitlementsFilePath)) {
        console.log('Entitlements file found. Reading...');
        try {
            entitlementsData = plist.parse(fs.readFileSync(entitlementsFilePath, 'utf-8'));
        } catch (e) {
            console.error(`Error reading entitlements file: ${e}. Will create/overwrite.`);
            entitlementsData = {};
        }
    } else {
        console.log('Entitlements file not found. Will create.');
        const entitlementsDir = path.dirname(entitlementsFilePath);
        if (!fs.existsSync(entitlementsDir)) {
            fs.mkdirSync(entitlementsDir, { recursive: true });
        }
    }

    if (entitlementsData[healthKitEntitlement] !== healthKitEntitlementValue) {
        console.log(`Adding/Updating ${healthKitEntitlement} entitlement...`);
        entitlementsData[healthKitEntitlement] = healthKitEntitlementValue;
        try {
            fs.writeFileSync(entitlementsFilePath, plist.build(entitlementsData), { encoding: 'utf-8' });
            console.log(`Successfully wrote entitlements file: ${entitlementsFilePath}`);
        } catch (e) {
            console.error(`Error writing entitlements file: ${e}`);
            return; // Stop if we can't write the entitlements file
        }
    } else {
        console.log(`${healthKitEntitlement} entitlement already set correctly in file.`);
    }

    // --- Modify Xcode Project Build Settings ---
    const xcodeProjPath = path.join(platformPath, `${projectName}.xcodeproj`, 'project.pbxproj');
    console.log(`Looking for Xcode project file at: ${xcodeProjPath}`);

    if (!fs.existsSync(xcodeProjPath)) {
        console.error('Error: Xcode project file not found.');
        return;
    }

    const xcodeProject = xcode.project(xcodeProjPath);

    try {
        xcodeProject.parseSync(); // Parse the project file

        let modified = false;
        const configurations = xcodeProject.pbxXCBuildConfigurationSection();
        for (const key in configurations) {
            // Filter out objects that aren't build configurations (like comments)
            if (key.endsWith('_comment')) continue;

            const config = configurations[key];
            if (config.buildSettings && config.buildSettings.PRODUCT_NAME === `"${projectName}"`) {
                 // Check if the setting is already correct
                 if (config.buildSettings.CODE_SIGN_ENTITLEMENTS !== `"${entitlementsRelativePath}"`) {
                    console.log(`Updating CODE_SIGN_ENTITLEMENTS for configuration: ${config.name}`);
                    config.buildSettings.CODE_SIGN_ENTITLEMENTS = `"${entitlementsRelativePath}"`;
                    modified = true;
                 } else {
                    console.log(`CODE_SIGN_ENTITLEMENTS already set correctly for configuration: ${config.name}`);
                 }
            }
        }

        if (modified) {
            // Write the modified project file back
            fs.writeFileSync(xcodeProjPath, xcodeProject.writeSync());
            console.log('Successfully updated Xcode project build settings.');
        } else {
            console.log('Xcode project build settings did not require modification.');
        }

    } catch (e) {
        console.error(`Error parsing or modifying Xcode project file: ${e}`);
    }

    console.log('add_healthkit_entitlement.js hook finished.');
};
