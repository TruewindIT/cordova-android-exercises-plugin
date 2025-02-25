var exec = require('cordova/exec');

var RequestExercisePermissionsPlugin = {
    requestPermissions: function(success, error){
        exec(success, error, 'RequestExercisePermissionsPlugin', 'requestPermissions', []);
    },
    getExerciseData: function(startTime, endTime, success, error) {
        exec(success, error, 'RequestExercisePermissionsPlugin', 'getExerciseData', [startTime, endTime]);
    }
};
module.exports = RequestExercisePermissionsPlugin;
