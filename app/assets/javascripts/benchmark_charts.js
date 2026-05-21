// Shared Chart.js and DataTable utilities for benchmark scatter charts.

function cleanModelName (name) {
  return name.replace(/\s*\(Reasoning\)\s*/gi, '').replace(/\s*\(Non-reasoning\)\s*/gi, '').trim();
}

function registerScatterChartPlugins () {
  if (typeof ChartDataLabels !== 'undefined') {
    Chart.register(ChartDataLabels);
  }
}

function scatterChartLayoutPadding () {
  return { left: 20, right: 20, top: 10, bottom: 10 };
}

function canvasEventCoords (canvas, evt) {
  var rect = canvas.getBoundingClientRect();
  var scaleX = canvas.width / rect.width;
  var scaleY = canvas.height / rect.height;
  return {
    x: (evt.clientX - rect.left) * scaleX,
    y: (evt.clientY - rect.top) * scaleY
  };
}

function labelHitTest (labelPositions, x, y) {
  for (var i = 0; i < labelPositions.length; i++) {
    var label = labelPositions[i];
    if (x >= label.x && x <= label.x + label.width &&
      y >= label.y && y <= label.y + label.height) {
      return label;
    }
  }
  return null;
}

function bindChartLabelInteractions (canvasEl, chart, labelPositions, onLabelClick) {
  var $canvas = $(canvasEl);

  $canvas.on('mousemove', function (evt) {
    var coords = canvasEventCoords(canvasEl, evt);
    var overLabel = labelHitTest(labelPositions, coords.x, coords.y);
    var overDataPoint = chart._hoveringDataPoint || false;
    canvasEl.style.cursor = (overLabel || overDataPoint) ? 'pointer' : 'default';
  });

  if (onLabelClick) {
    $canvas.on('click', function (evt) {
      var coords = canvasEventCoords(canvasEl, evt);
      var label = labelHitTest(labelPositions, coords.x, coords.y);
      if (label) onLabelClick(label);
    });
  }
}

function updateTableScoreRanks (table, columns) {
  var visibleRows = table.rows({ search: 'applied' }).nodes();

  columns.forEach(function (col) {
    var includeScore = col.includeScore || function (score) { return score >= 0; };
    var nanScore = col.nanScore != null ? col.nanScore : -1;

    $('td.' + col.cellClass + ' .rank-display').text('');
    var scores = [];

    $(visibleRows).each(function () {
      var cell = $(this).find('td.' + col.cellClass);
      if (!cell.length) return;

      var score = parseFloat(cell.data('order'));
      if (isNaN(score)) score = nanScore;
      if (includeScore(score)) {
        scores.push({ score: score, cell: cell });
      }
    });

    scores.sort(function (a, b) { return b.score - a.score; });

    var currentRank = 1;
    scores.forEach(function (item, idx) {
      if (idx > 0 && scores[idx - 1].score !== item.score) {
        currentRank = idx + 1;
      }
      item.cell.find('.rank-display').text('(' + currentRank + '/' + scores.length + ')');
    });
  });
}

// Chart.js plugin: leader lines from scatter points to labels with collision avoidance.
function createLeaderLinePlugin (options) {
  options = options || {};
  var labelHeight = options.labelHeight || 12;
  var labelPadding = options.labelPadding || 4;
  var baseLineLength = options.baseLineLength || 25;
  var maxLineLength = options.maxLineLength || 200;
  var lineLengthStep = options.lineLengthStep || 10;
  var pointRadius = options.pointRadius || 12;
  var shouldLabel = options.shouldLabel || function (dataPoint) { return !!dataPoint.label; };
  var formatLabel = options.formatLabel || function (dataPoint) { return dataPoint.label; };
  var labelPositions = options.labelPositions || null;
  var getLabelMeta = options.getLabelMeta || function () { return {}; };

  return {
    id: 'leaderLines',
    afterDatasetsDraw: function (chart) {
      var ctx = chart.ctx;
      var labels = [];
      var allPoints = [];

      if (labelPositions) labelPositions.length = 0;

      var chartArea = chart.chartArea;

      function pointInChartArea (x, y) {
        return x >= chartArea.left && x <= chartArea.right &&
          y >= chartArea.top && y <= chartArea.bottom;
      }

      chart.data.datasets.forEach(function (dataset, datasetIndex) {
        if (dataset.type === 'line') return;
        var meta = chart.getDatasetMeta(datasetIndex);
        meta.data.forEach(function (element, index) {
          var dataPoint = dataset.data[index];
          if (!shouldLabel(dataPoint)) return;
          if (element.skip || element.hidden) return;
          if (!pointInChartArea(element.x, element.y)) return;

          var labelText = formatLabel(dataPoint);
          ctx.font = '10px sans-serif';
          var textWidth = ctx.measureText(labelText).width;

          labels.push({
            label: labelText,
            pointX: element.x,
            pointY: element.y,
            textWidth: textWidth,
            angle: 0,
            lineLength: baseLineLength,
            meta: getLabelMeta(dataPoint)
          });
          allPoints.push({ x: element.x, y: element.y });
        });
      });

      labels.sort(function (a, b) { return b.pointX - a.pointX; });

      var axisBottom = chartArea.bottom;

      function calcLabelBox (lbl) {
        var endX = lbl.pointX + Math.cos(lbl.angle) * lbl.lineLength;
        var endY = lbl.pointY + Math.sin(lbl.angle) * lbl.lineLength;
        return {
          x: endX + labelPadding,
          y: endY - labelHeight / 2,
          width: lbl.textWidth,
          height: labelHeight,
          endX: endX,
          endY: endY
        };
      }

      function boxBelowAxis (box) {
        return box.endY > axisBottom || (box.y + box.height) > axisBottom;
      }

      function boxesOverlap (a, b) {
        return !(a.x + a.width < b.x || b.x + b.width < a.x ||
          a.y + a.height < b.y || b.y + b.height < a.y);
      }

      function boxOverlapsPoint (box, point) {
        var closestX = Math.max(box.x, Math.min(point.x, box.x + box.width));
        var closestY = Math.max(box.y, Math.min(point.y, box.y + box.height));
        var dx = point.x - closestX;
        var dy = point.y - closestY;
        return (dx * dx + dy * dy) < (pointRadius * pointRadius);
      }

      var angles = [-Math.PI / 8, Math.PI / 8, -Math.PI / 6, Math.PI / 6, -Math.PI / 4, Math.PI / 4, -Math.PI / 3, Math.PI / 3, -Math.PI / 2.5, Math.PI / 2.5, -Math.PI / 2, 0];
      var lengths = [];
      for (var len = baseLineLength; len <= maxLineLength; len += lineLengthStep) {
        lengths.push(len);
      }

      function lineAngleScore (angle) {
        if (Math.abs(angle) < 0.01) return 100;
        var abs = Math.abs(angle);
        if (abs >= Math.PI / 12 && abs <= Math.PI / 4) {
          return Math.abs(abs - Math.PI / 8) * 10;
        }
        return 30 + Math.abs(abs - Math.PI / 8) * 15;
      }

      for (var i = 0; i < labels.length; i++) {
        var currentLabel = labels[i];
        var bestConfig = { angle: 0, lineLength: baseLineLength, collisions: Infinity };

        for (var ai = 0; ai < angles.length; ai++) {
          for (var li = 0; li < lengths.length; li++) {
            currentLabel.angle = angles[ai];
            currentLabel.lineLength = lengths[li];
            var currentBox = calcLabelBox(currentLabel);
            var collisionCount = 0;

            for (var j = 0; j < i; j++) {
              if (boxesOverlap(currentBox, calcLabelBox(labels[j]))) {
                collisionCount++;
              }
            }

            for (var p = 0; p < allPoints.length; p++) {
              if (boxOverlapsPoint(currentBox, allPoints[p])) {
                collisionCount++;
              }
            }

            if (boxBelowAxis(currentBox)) {
              collisionCount += 1000;
            }

            var score = collisionCount * 1000 + lengths[li] + lineAngleScore(angles[ai]);
            if (score < bestConfig.collisions * 1000 + bestConfig.lineLength + lineAngleScore(bestConfig.angle)) {
              bestConfig = { angle: angles[ai], lineLength: lengths[li], collisions: collisionCount };
            }

            if (collisionCount === 0) break;
          }
        }

        currentLabel.angle = bestConfig.angle;
        currentLabel.lineLength = bestConfig.lineLength;
      }

      labels.forEach(function (lbl) {
        if (!pointInChartArea(lbl.pointX, lbl.pointY)) return;

        var box = calcLabelBox(lbl);
        var endX = box.endX;
        var endY = Math.min(box.endY, axisBottom - 2);
        var textY = Math.min(box.endY, axisBottom - labelHeight / 2 - 2);

        ctx.save();
        ctx.beginPath();
        ctx.moveTo(lbl.pointX, lbl.pointY);
        ctx.lineTo(endX, endY);
        ctx.strokeStyle = '#999';
        ctx.lineWidth = 1;
        ctx.stroke();

        ctx.font = '10px sans-serif';
        ctx.fillStyle = '#666';
        ctx.textBaseline = 'middle';
        ctx.textAlign = 'left';
        ctx.fillText(lbl.label, endX + labelPadding, textY);
        ctx.restore();

        if (labelPositions) {
          labelPositions.push(Object.assign({
            x: endX + labelPadding,
            y: textY - labelHeight / 2,
            width: box.width,
            height: box.height
          }, lbl.meta));
        }
      });
    }
  };
}
