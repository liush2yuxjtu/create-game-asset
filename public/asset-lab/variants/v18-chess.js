import { createVariant } from '../variant-engine.js';
// Original motion descriptor; shared drawing machinery lives in variant-engine.js.
export default createVariant({
  "id": "v18",
  "number": 18,
  "name": "骨牌封途",
  "family": "chess",
  "familyName": "落子定局",
  "variant": 2,
  "description": "骨牌逐张倾倒，关上退路",
  "motion": "链式倒伏",
  "duration": 5.4,
  "previewAt": 0.49,
  "seed": 306
});
