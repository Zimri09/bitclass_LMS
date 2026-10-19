import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { decodeSourceText, hasReadableSource } from './source_text.ts';

test('short UTF-8 source is accepted without a 200-character minimum', () => {
  const text = decodeSourceText(new TextEncoder().encode('A bit is a binary digit.'));
  assert.equal(hasReadableSource(text), true);
  assert.equal(hasReadableSource(' \n\t'), false);
});
test('Windows UTF-16 BOM text is decoded losslessly', () => {
  assert.equal(decodeSourceText(Uint8Array.from([255, 254, 72, 0, 105, 0])), 'Hi');
  assert.equal(decodeSourceText(Uint8Array.from([254, 255, 0, 72, 0, 105])), 'Hi');
});
test('invalid encoding and binary data are still rejected', () => {
  assert.throws(() => decodeSourceText(Uint8Array.from([255])));
  assert.throws(() => decodeSourceText(Uint8Array.from([65, 0])));
});
