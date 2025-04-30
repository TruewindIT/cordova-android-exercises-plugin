// --- Test Health Plugin ---
const healthPlugin = cordova.plugins.RequestExercisePermissionsPlugin;

if (!healthPlugin) {
    console.error('Health Plugin not found!');
    return;
}

// 1. Request Permissions
healthPlugin.requestPermissions(
    function(successMsg) {
        console.log('Permission request success:', successMsg);

        // 2. Get Exercise Data for January of the current year
        const currentYear = new Date().getFullYear();
        // Note: JavaScript months are 0-indexed (0 = January)
        const startDate = new Date(currentYear, 3, 1, 0, 0, 0, 0); // Jan 1st, 00:00:00
        const endDate = new Date(currentYear, 4, 1, 0, 0, 0, 0);   // Feb 1st, 00:00:00 (Query is exclusive of end date)

        // Format dates as ISO 8601 strings
        const startDateISO = startDate.toISOString();
        const endDateISO = endDate.toISOString();

        console.log(`Fetching data from ${startDateISO} to ${endDateISO} (Month of January ${currentYear})`);

        healthPlugin.getExerciseData(
            startDateISO,
            endDateISO,
            function(jsonData) {
                console.log('Exercise data received (JSON string):', jsonData);
                try {
                    const data = JSON.parse(jsonData);
                    console.log('Parsed exercise data:', data);
                    // Display data in the app's UI if desired
                } catch (e) {
                    console.error('Error parsing JSON data:', e);
                }
            },
            function(errorMsg) {
                console.error('Error getting exercise data:', errorMsg);
            }
        );

    },
    function(errorMsg) {
        console.error('Permission request error:', errorMsg);
    }
);
// --- End Test Health Plugin ---