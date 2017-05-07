var fs = require("fs"),
    path = require("path"),
    proc = require('child_process');
    //zip = require('zip');
    //zip = require("adm-zip");
    
var MESH2_WIDTH = 1125,
    MESH2_HEIGHT = 750,
    MESH1_WIDTH = MESH2_WIDTH * 8,
    MESH1_HEIGHT = MESH2_HEIGHT * 8;
    
var buffer = Buffer.allocUnsafe(MESH1_WIDTH * MESH1_HEIGHT * 2);

var makeBins = function (rootDir, size, method) {
    var files = fs.readdirSync(rootDir),
        i, n,
        file, stat;
    
    for (i = 0, n = files.length; i < n; i++) {
        file = path.join(rootDir, files[i]);
        stat = fs.statSync(file);
        if (stat.isDirectory()) {
            console.log("> " + files[i] + " start.");
            makeMeshBin(file, size, method);
            console.log("> " + files[i] + " end.");
        }
    }
};

var makeMeshBin = function (dir, size, method) {
    var files = fs.readdirSync(dir),
        i, n,
        file;
        
    buffer.fill(0);
    for (i = 0, n = files.length; i < n; i++) {
        file = path.join(dir, files[i]);
        if (file.indexOf("-DEM10B.zip") > 0) {
            console.log(">> " + files[i] + " start.");
            readSubMesh(file);
            console.log(">> " + files[i] + " end.");
        }
    }
    writeToBin(dir + "_" + method + "_" + size + ".bin", size, method)
}

var readSubMesh = function(file) {
    var workDir = file + "work";
    fs.mkdirSync(workDir);
    proc.execSync("unzip " + file + " -d " + workDir); 
    var files = fs.readdirSync(workDir)
    var workFile = path.join(workDir, files[0]);
    var mx = parseInt(files[0].substr(13, 1));
    var my = parseInt(files[0].substr(12, 1));
    var data = fs.readFileSync(workFile);
    var contents = data.toString("utf-8");

    var start = 0, len = contents.length;
    var dataStart = 0, dataEnd = 0;
    var dataIndex = 0;
    while (start < len) {
        var end = contents.indexOf("\r\n", start);
        var line = contents.substring(start, end);
        start = end + 2;
        if (line.indexOf("<gml:low>") >= 0) {
            if (line.indexOf("0 0") < 0) {
                throw "gml:low != 0 0";
            }
        } else if (line.indexOf("<gml:high>") >= 0) {
            if (line.indexOf("1124 749") < 0) {
                throw "gml:high != 1124 749";
            }
        } else if (line.indexOf("<gml:tupleList>") >= 0) {
            dataStart = start;
            dataEnd = contents.indexOf("</gml:tupleList>", start);
            end = contents.indexOf("\r\n", dataEnd);
            start = end + 2;
        } else if (line.indexOf("<gml:startPoint>") >= 0) {
            var s = line.indexOf(">") + 1;
            var e = line.indexOf("<", s);
            var nums = line.substring(s, e).split(" ");
            dataIndex = parseInt(nums[1]) * MESH2_WIDTH + parseInt(nums[0])
        }
    }
    
    var buf = Buffer.alloc(MESH2_WIDTH * MESH2_HEIGHT * 2);
    start = dataStart;
    while (start < dataEnd) {
        end = contents.indexOf("\r\n", start);
        line = contents.substring(start, end);
        start = end + 2;
        var parts = line.split(",");
        var h = Math.max(parseFloat(parts[1]), 0.0);
        var dx = dataIndex % MESH2_WIDTH;
        var dy = Math.floor(dataIndex / MESH2_WIDTH);
        var x = mx * MESH2_WIDTH + dx;
        var y = my * MESH2_HEIGHT + (MESH2_HEIGHT - dy) - 1;
        var offset = (y * MESH1_WIDTH + x) * 2;
        var hv = Math.round(h * 10);
        try {
            buffer.writeUInt16LE(hv, offset);
        } catch (e) {
            console.log(dataIndex + ":" + contents.substr(start, 20));
            console.log("h=" + hv + " x=" + x  + " y=" + y + " offset=" + offset);
            throw e;
        }
        dataIndex++;
    }
    fs.unlinkSync(workFile);
    fs.rmdirSync(workDir);
}

var writeToBin = function (file, size, method) {
    var width = MESH1_WIDTH / size;
    var height = MESH1_HEIGHT / size;
    var max = 0;
    var wb = Buffer.alloc(width * height * 2);
    for (var h = 0; h < height; h++) {
        for (var w = 0; w < width; w++) {
            var val = [];
            for (var y = 0; y < size; y++) {
                for (var x = 0; x < size; x++) {
                    var mx = w * size + x;
                    var my = h * size + y;
                    var offset = (my * MESH1_WIDTH + mx) * 2;
                    val.push(buffer.readUInt16LE(offset));
                }
            }
            var wo = (h * width + w) * 2;
            var hv = getHeightValue(val, method);
            if (hv > max) {
                max = hv;
            }
            wb.writeUInt16LE(getHeightValue(val, method), wo);
        }
    }
    var fd = fs.openSync(file, "w");
    fs.writeSync(fd, wb);
    fs.closeSync(fd);
    console.log("max:" + (max / 10));
}

var getHeightValue = function (val, method) {
    if (method !== "AVG") {
        val.sort(function(a, b) {return b - a;});
    }
    if (method === "MAX") {
        return val[0];
    }
    if (method.substr(0, 3) === "NTH") {
        return val[parseInt(method.substring(3))];
    }
    var avg = Math.round(val.reduce(function(prev, elem) {return prev + elem;}) / size / size);
    if (method === "AVG") {
        return avg;
    } else {
        return Math.round((avg + val[0]) / 2);
    }
}

if (process.argv.length < 3) {
  console.log('usage: node dembin.js rootDir');
  return;
}

buffer.fill(0);
makeBins(process.argv[2], 10, "MAX");
// readSubMesh("/Users/zak/nodeapps/landscape/FG-GML-4830-07-DEM10B.zip");
