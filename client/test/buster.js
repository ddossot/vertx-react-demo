var config = exports;

config['Browser Tests'] = {
    rootPath: "../",
    environment: 'browser',
    sources: [],
    extensions: [require("buster-coffee")],
    tests: ["test/*test.coffee"]
};
