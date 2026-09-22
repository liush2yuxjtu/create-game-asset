// Original Qinglan UI rehearsal only; this does not mutate gameplay or grant rewards.
export function sampleRehearsal(time){
 if(!Number.isFinite(time))throw new TypeError('time must be finite');
 const t=Math.max(0,Math.min(3.2,time));
 return {health:t>=1.2?64:100,complete:t>=3.2,
 phase:t>=3.2?'演练结束':t>=1.8?'消散':t>=1.1?'斩击':'蓄势',
 message:t>=3.2?'演练完成。':t>=1.8?'剑意消散，等待归息。':t>=1.2?'命中提示 · 模拟伤害 36':t>=1.1?'剑阵斩出。':'蓄势聚灵。'};
}
