const test = require('node:test');
const assert = require('node:assert/strict');
const { frameToPhotoCrop } = require('../.test-dist/cropRect.js');

test('landscape photo cover crop maps centered frame', () => {
  assert.deepEqual(frameToPhotoCrop({ x: 100, y: 250, width: 300, height: 250 }, { x: 0, y: 0, width: 500, height: 800 }, { width: 1600, height: 900 }), { x: 631, y: 281, width: 338, height: 282 });
});

test('portrait photo cover crop maps frame with horizontal crop', () => {
  assert.deepEqual(frameToPhotoCrop({ x: 100, y: 250, width: 300, height: 250 }, { x: 0, y: 0, width: 500, height: 800 }, { width: 900, height: 1600 }), { x: 180, y: 530, width: 540, height: 450 });
});

test('nonmatching camera origin and bounds clamp to photo', () => {
  assert.deepEqual(frameToPhotoCrop({ x: -200, y: -10, width: 1000, height: 900 }, { x: 10, y: 20, width: 500, height: 800 }, { width: 1000, height: 1000 }), { x: 0, y: 0, width: 1000, height: 1000 });
});

test('invalid dimensions reject the crop before native manipulation', () => {
  assert.throws(() => frameToPhotoCrop({ x: 0, y: 0, width: 1, height: 1 }, { x: 0, y: 0, width: 0, height: 1 }, { width: 1, height: 1 }));
  assert.throws(() => frameToPhotoCrop({ x: NaN, y: 0, width: 1, height: 1 }, { x: 0, y: 0, width: 1, height: 1 }, { width: 1, height: 1 }));
});

test('translated camera and frame coordinates give the same crop', () => {
  assert.deepEqual(frameToPhotoCrop({ x: 60, y: 120, width: 200, height: 100 }, { x: 10, y: 20, width: 300, height: 400 }, { width: 3000, height: 4000 }), { x: 500, y: 1000, width: 2000, height: 1000 });
});

test('offscreen frames are rejected and fractional edges stay within bounds', () => {
  assert.throws(() => frameToPhotoCrop({ x: 500, y: 0, width: 10, height: 10 }, { x: 0, y: 0, width: 100, height: 100 }, { width: 1000, height: 1000 }));
  const crop = frameToPhotoCrop({ x: 0.06, y: 0.06, width: 99.94, height: 99.94 }, { x: 0, y: 0, width: 100, height: 100 }, { width: 999, height: 999 });
  assert.equal(crop.x + crop.width, 999);
  assert.equal(crop.y + crop.height, 999);
});
