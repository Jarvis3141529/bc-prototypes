// ONNX Runtime Web digit recognizer for MNIST
let session = null;

async function initRecognizer() {
  if (session) return;
  try {
    session = await ort.InferenceSession.create('./mnist.onnx');
    console.log('MNIST model loaded');
  } catch (e) {
    console.error('Failed to load MNIST model:', e);
  }
}

// Call on page load
initRecognizer();

/**
 * Recognize a digit from stroke data.
 * strokesJson: JSON string of [[[x,y],[x,y],...], ...] (list of strokes, each stroke is list of points)
 * canvasWidth, canvasHeight: dimensions of the drawing canvas
 * Returns JSON string: { "digit": 3, "confidence": 0.95 }
 */
async function recognizeDigit(strokesJson, canvasWidth, canvasHeight) {
  if (!session) {
    await initRecognizer();
    if (!session) return JSON.stringify({ digit: -1, confidence: 0 });
  }

  const strokes = JSON.parse(strokesJson);
  if (strokes.length === 0) return JSON.stringify({ digit: -1, confidence: 0 });

  // Render strokes onto hidden 28x28 canvas
  const canvas = document.getElementById('hiddenCanvas');
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, 28, 28);
  ctx.fillStyle = 'black';
  ctx.fillRect(0, 0, 28, 28);

  // Find bounding box of all strokes
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const stroke of strokes) {
    for (const [x, y] of stroke) {
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }

  // Add padding
  const pad = Math.max((maxX - minX), (maxY - minY)) * 0.15;
  minX -= pad; minY -= pad; maxX += pad; maxY += pad;

  // Scale to fit 20x20 centered in 28x28 (MNIST convention)
  const bw = maxX - minX || 1;
  const bh = maxY - minY || 1;
  const scale = 20 / Math.max(bw, bh);
  const offsetX = (28 - bw * scale) / 2 - minX * scale;
  const offsetY = (28 - bh * scale) / 2 - minY * scale;

  ctx.strokeStyle = 'white';
  ctx.lineWidth = 2.5;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  for (const stroke of strokes) {
    if (stroke.length === 0) continue;
    ctx.beginPath();
    ctx.moveTo(stroke[0][0] * scale + offsetX, stroke[0][1] * scale + offsetY);
    for (let i = 1; i < stroke.length; i++) {
      ctx.lineTo(stroke[i][0] * scale + offsetX, stroke[i][1] * scale + offsetY);
    }
    ctx.stroke();
  }

  // Extract pixel data and normalize
  const imageData = ctx.getImageData(0, 0, 28, 28);
  const input = new Float32Array(1 * 1 * 28 * 28);
  for (let i = 0; i < 784; i++) {
    // Use red channel (grayscale), normalize to 0-1
    input[i] = imageData.data[i * 4] / 255.0;
  }

  // Run inference
  const tensor = new ort.Tensor('float32', input, [1, 1, 28, 28]);
  const results = await session.run({ 'Input3': tensor });
  const output = results['Plus214_Output_0'].data;

  // Softmax
  let maxVal = -Infinity;
  for (let i = 0; i < 10; i++) maxVal = Math.max(maxVal, output[i]);
  let sum = 0;
  const probs = new Float32Array(10);
  for (let i = 0; i < 10; i++) {
    probs[i] = Math.exp(output[i] - maxVal);
    sum += probs[i];
  }
  for (let i = 0; i < 10; i++) probs[i] /= sum;

  // Find best
  let bestDigit = 0;
  let bestConf = 0;
  for (let i = 0; i < 10; i++) {
    if (probs[i] > bestConf) {
      bestConf = probs[i];
      bestDigit = i;
    }
  }

  return JSON.stringify({ digit: bestDigit, confidence: bestConf });
}
