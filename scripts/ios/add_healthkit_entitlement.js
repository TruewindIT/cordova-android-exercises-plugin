#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');
const plist = require('plist'); // Requires `npm install plist` or adding it to plugin's package.json devDependencies

module.exports = function(context) {
    console.log('Executing add_healthkit_entitlement.js hook...');

    const projectRoot = context.opts.projectRoot;
    const platformPath = path.join(projectRoot, 'platforms', 'ios');
    const healthKitEntitlement = 'com.apple.developer.healthkit';
    const healthKitEntitlementValue = true;

    // Find the project name
    // Cordova typically names the Xcode project similarly to the app name in config.xml
    // A more robust way might involve parsing config.xml or looking for the .xcodeproj directory
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
        // Fallback: try finding the .xcodeproj directory
        const platformContents = fs.readdirSync(platformPath);
        projectName = platformContents.find(item => item.endsWith('.xcodeproj'))?.replace('.xcodeproj', '');
    }

    if (!projectName) {
        console.error('Error: Could not determine project name to find entitlements file.');
        return; // Exit script
    }
    console.log(`Determined project name: ${projectName}`);

    // Construct the path to the entitlements file.
    // Note: The exact name and location might vary based on Cordova/Xcode versions.
    // Common location is platforms/ios/ProjectName/ProjectName.entitlements
    const entitlementsFileName = `${projectName}.entitlements`;
    const entitlementsFilePath = path.join(platformPath, projectName, entitlementsFileName);

    console.log(`Looking for entitlements file at: ${entitlementsFilePath}`);

    let entitlementsData = {};

    if (fs.existsSync(entitlementsFilePath)) {
        console.log('Entitlements file found. Reading...');
        try {
            const entitlementsContent = fs.readFileSync(entitlementsFilePath, 'utf-8');
            entitlementsData = plist.parse(entitlementsContent);
            console.log('Existing entitlements:', JSON.stringify(entitlementsData));
        } catch (e) {
            console.error(`Error reading entitlements file: ${e}. Creating new one.`);
            // Reset data if file is corrupted
            entitlementsData = {};
        }
    } else {
        console.log('Entitlements file not found. Creating a new one.');
        // Ensure the directory exists
        const entitlementsDir = path.dirname(entitlementsFilePath);
        if (!fs.existsSync(entitlementsDir)){
             console.log(`Creating directory: ${entitlementsDir}`);
             fs.mkdirSync(entitlementsDir, { recursive: true });
        }
    }

    // Add or update the HealthKit entitlement
    if (entitlementsData[healthKitEntitlement] !== healthKitEntitlementValue) {
        console.log(`Adding/Updating ${healthKitEntitlement} entitlement...`);
        entitlementsData[healthKitEntitlement] = healthKitEntitlementValue;

        // Write the updated entitlements file
        try {
            const updatedEntitlementsContent = plist.build(entitlementsData);
            fs.writeFileSync(entitlementsFilePath, updatedEntitlementsContent, { encoding: 'utf-8' });
            console.log(`Successfully updated entitlements file: ${entitlementsFilePath}`);
        } catch (e) {
            console.error(`Error writing entitlements file: ${e}`);
        }
    } else {
        console.log(`${healthKitEntitlement} entitlement already set correctly.`);
    }

    // Additionally, ensure the project file links this entitlement file
    // This part is harder and often requires the 'xcode' module.
    // For many setups, just having the file present and named correctly is enough
    // if the capability was ever added manually once, or if using newer Cordova/Xcode.
    // We'll skip direct .pbxproj modification for now as it's complex and fragile.
    console.log('add_healthkit_entitlement.js hook finished.');
};
