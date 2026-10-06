'use strict';
(() => {
  const byId = id => document.getElementById(id);
  const canvas = byId('canvas');
  const tokens = new Map();
  let ready = false, starting = false, lastMode = '', menuSignature = '', padPointer = null;
  const active = new Set();
  function isolateButtonKeyboard(button) {
    // An HTML button's Enter/Space click must not also confirm the canvas menu.
    for (const type of ['keydown','keyup']) button.addEventListener(type, event => {
      event.stopPropagation();
      if (event.repeat && ['Enter',' '].includes(event.key)) event.preventDefault();
    });
  }
  document.querySelectorAll('button').forEach(isolateButtonKeyboard);
  function emit(action, pressed) {
    if (typeof window.emberwakeInput === 'function') window.emberwakeInput(action, pressed);
  }
  function sync() {
    const desired = new Set([...tokens.values()].flat());
    for (const action of active) if (!desired.has(action)) { emit(action, false); active.delete(action); }
    for (const action of desired) if (!active.has(action)) { emit(action, true); active.add(action); }
    document.querySelectorAll('[data-action]').forEach(b => b.classList.toggle('pressed', active.has(b.dataset.action)));
  }
  function setToken(id, actions) { if (actions.length) tokens.set(id, actions); else tokens.delete(id); sync(); }
  function releaseAll(pause = false) {
    tokens.clear(); sync(); padPointer = null; byId('stick').style.transform = '';
    if (pause && typeof window.emberwakeInput === 'function') window.emberwakeInput('blur');
  }
  document.querySelectorAll('[data-action]').forEach(button => {
    button.addEventListener('pointerdown', event => {
      if (!ready || event.button > 0) return;
      event.preventDefault(); button.setPointerCapture(event.pointerId);
      setToken(event.pointerId, [button.dataset.action]);
    });
    for (const name of ['pointerup','pointercancel','lostpointercapture']) button.addEventListener(name, e => setToken(e.pointerId, []));
    // Keyboard activation for the accessible HTML buttons uses a complete press/release.
    button.addEventListener('click', event => { if (event.detail === 0 && ready) { emit(button.dataset.action, true); emit(button.dataset.action, false); } });
  });
  const pad = byId('direction-pad');
  function movePad(event) {
    if (event.pointerId !== padPointer) return;
    const rect = pad.getBoundingClientRect();
    const x = (event.clientX - rect.left - rect.width / 2) / (rect.width / 2);
    const y = (event.clientY - rect.top - rect.height / 2) / (rect.height / 2);
    const actions = [];
    if (x < -.25) actions.push('left'); if (x > .25) actions.push('right');
    if (y < -.32) actions.push('up'); if (y > .32) actions.push('down');
    setToken(event.pointerId, actions);
    byId('stick').style.transform = `translate(${Math.max(-1,Math.min(1,x))*25}px,${Math.max(-1,Math.min(1,y))*25}px)`;
  }
  pad.addEventListener('pointerdown', e => { if (!ready || padPointer !== null) return; e.preventDefault(); padPointer=e.pointerId; pad.setPointerCapture(e.pointerId); movePad(e); });
  pad.addEventListener('pointermove', movePad);
  for (const name of ['pointerup','pointercancel','lostpointercapture']) pad.addEventListener(name, e => { if (e.pointerId !== padPointer) return; setToken(e.pointerId,[]); padPointer=null; byId('stick').style.transform=''; });
  window.addEventListener('blur', () => releaseAll(true));
  document.addEventListener('visibilitychange', () => { if (document.hidden) releaseAll(true); });
  window.addEventListener('pagehide', () => releaseAll(true));
  byId('fullscreen').addEventListener('click', () => {
    if (document.fullscreenElement) document.exitFullscreen?.();
    else if (byId('app').requestFullscreen) byId('app').requestFullscreen().catch(() => { byId('save-status').textContent='当前浏览器未开启全屏，可以继续游玩。'; });
    else byId('save-status').textContent='此浏览器不提供网页全屏，请将手机横放。';
  });
  byId('sound').addEventListener('click', () => { if (ready) { emit('mute',true); emit('mute',false); } });
  window.emberwakeState = encoded => {
    const state = JSON.parse(encoded); ready=true;
    if (lastMode !== state.mode) { releaseAll(); lastMode=state.mode; }
    byId('loading').hidden=true; byId('stage').classList.remove('booting');
    const menu = ['title','pause'].includes(state.mode), reading=['dialog','ending'].includes(state.mode);
    byId('touch-deck').hidden=menu || reading;
    byId('menu-panel').hidden=!menu; byId('reading-panel').hidden=!reading;
    byId('menu-heading').textContent=state.mode === 'title' ? '点亮灯火，开始旅途' : '旅途已暂停';
    const options = byId('menu-options');
    const signature=JSON.stringify([state.mode,state.options]);
    if (signature!==menuSignature) {
      const focusedIndex=Array.from(options.children).indexOf(document.activeElement);
      options.replaceChildren(); menuSignature=signature;
      for (let index=0;index<state.options.length;index++) {
        const button=document.createElement('button'); button.textContent=state.options[index];
        isolateButtonKeyboard(button);
        button.addEventListener('click',()=> { releaseAll(); window.emberwakeInput(`menu:${index}`); if (!['title','pause'].includes(lastMode)) canvas.focus({preventScroll:true}); });
        options.append(button);
      }
      if (menu && focusedIndex>=0 && options.children.length) options.children[Math.min(focusedIndex,options.children.length-1)].focus({preventScroll:true});
    }
    Array.from(options.children).forEach((button,index)=>button.setAttribute('aria-current',String(index===state.selected)));
    byId('reading-title').textContent=state.dialog.title || '';
    byId('reading-text').textContent=state.dialog.text || '';
    byId('sound').textContent=state.sound ? '声音：开' : '声音：关';
    byId('sound').setAttribute('aria-pressed',String(state.sound));
    byId('save-status').textContent=state.save_error || (!state.persistent ? '浏览器未提供持久存储，关闭网页后进度可能丢失。' : (state.save_count ? '已记录旅途。' : '')+'进度保存在当前浏览器；请勿用无痕模式或清理网站数据。');
    window.emberwakeLastState=state;
  };
  function failure(message) { byId('loading').hidden=false; byId('start').hidden=true; byId('progress').hidden=true; byId('load-text').textContent=message; }
  byId('start').addEventListener('click', async () => {
    if (starting) return; starting=true; byId('start').disabled=true;
    if (typeof Engine !== 'function') { failure('游戏引擎未下载完成，请刷新页面重试。'); return; }
    const missing=Engine.getMissingFeatures({threads:window.EMBERWAKE_THREADS});
    if (missing.length) { failure('此浏览器暂时无法运行 Godot 游戏：'+missing.join('、')+'。请用支持 WebGL 2 的 Safari 或 Chrome 打开。'); return; }
    try {
      const engine=new Engine(window.EMBERWAKE_CONFIG);
      window.emberwakeEngine=engine;
      await engine.startGame({canvas,canvasResizePolicy:0,onProgress:(current,total)=> {
        byId('load-text').textContent=total ? `正在载入 ${Math.round(current/total*100)}%` : '正在准备游戏…';
        if(total)byId('progress').value=current/total;
      },onPrintError:(...args)=>console.error('[EMBERWAKE]',...args)});
      canvas.focus({preventScroll:true});
    } catch(error) { failure('载入未完成：'+String(error.message || error)+'。请刷新重试，或检查浏览器是否支持 WebGL 2。'); }
  });
  // Keep a fixed 640×360 render grid: CSS scales it crisply without allocating a phone-sized framebuffer.
  canvas.width=640;canvas.height=360;
  window.emberwakeReleaseInputs=releaseAll;
})();
