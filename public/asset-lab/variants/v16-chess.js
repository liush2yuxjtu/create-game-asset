import { createVariant } from '../variant-engine.js';
// Original motion descriptor; shared drawing machinery lives in variant-engine.js.
export default createVariant({
  "id": "v16",
  "number": 16,
  "name": "天元落子",
  "family": "chess",
  "familyName": "落子定局",
  "variant": 0,
  "description": "四白先落，一黑锁定方寸",
  "motion": "方形封锁",
  "duration": 4.6,
  "previewAt": 0.49,
  "seed": 272
});
