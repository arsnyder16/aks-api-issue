'use strict';
const process = require('process');
const k8s = require('@kubernetes/client-node');
const kc = new k8s.KubeConfig();
kc.loadFromCluster();
const k8Core = kc.makeApiClient(k8s.CoreV1Api);
let startTime; // custom log offset to help correlate with tcp dump
const log = msg => console.log(`${(new Date() - startTime) / 1000.0} ${msg}`);
let running;
let interval;
const listPods = async ()=>{
  if (running) {
    return;
  }
  running = true;
  log('Listing pods...');
  const listStart = new Date();
  const { body: { items } } = await k8Core.listNamespacedPod('default');
  const seconds = (new Date() - listStart) / 1000.0;
  log(`Found ${items.length} pods in ${seconds} seconds`);
  if(seconds > 60) {
    log(`Closing because this seems excessive`);
    process.exitCode = -1;
    clearInterval(interval);
    return;
  }
  running = false;
};
setTimeout(()=>{
  startTime = new Date();
  listPods();
  interval = setInterval(listPods, 215 * 1000);
}, 1000)
