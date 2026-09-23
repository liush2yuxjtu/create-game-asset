import { createVariant } from '../variant-engine.js';
// Original motion descriptor; shared drawing machinery lives in variant-engine.js.
export default createVariant({
  "id": "v17",
  "number": 17,
  "name": "星局移宫",
  "family": "chess",
  "familyName": "落子定局",
  "variant": 1,
  "description": "六子移位，星线突然扣合",
  "motion": "六点换位",
  "duration": 5.0,
  "previewAt": 0.49,
  "seed": 289
});
