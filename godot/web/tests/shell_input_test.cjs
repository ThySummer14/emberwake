// DOM/event simulation of our shell input routing, not a browser/WebGL playtest.
const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
class Element {
 constructor(id=''){this.id=id;this.listeners={};this.dataset={};this.style={};this.children=[];this.hidden=false;this.classList={toggle(){},remove(){}};}
 addEventListener(k,f){(this.listeners[k]??=[]).push(f)}
 fire(k,e={}){for(const f of this.listeners[k]||[])f({preventDefault(){},button:0,...e})}
 setPointerCapture(){} getBoundingClientRect(){return {left:0,top:0,width:140,height:140}} focus(){document.activeElement=this}
 setAttribute(){} replaceChildren(){this.children=[]} append(x){this.children.push(x)}
}
const ids=['stage','canvas','stick','direction-pad','fullscreen','app','save-status','sound','loading','touch-deck','menu-panel','reading-panel','menu-heading','menu-options','reading-title','reading-text','start','progress','load-text'];
const elements=Object.fromEntries(ids.map(k=>[k,new Element(k)]));
const actions=['map','pause','interact','heal','attack','dash','jump'].map(action=>{const e=new Element();e.dataset.action=action;return e});
const document=new Element();Object.assign(document,{getElementById:id=>elements[id],querySelectorAll:()=>actions,createElement:()=>new Element()});
const window=new Element();const events=[];window.emberwakeInput=(...a)=>events.push(a);
vm.runInNewContext(fs.readFileSync(require('path').join(__dirname,'../shell.js'),'utf8'),{document,window,console,Set,Map,JSON,Math,String,Engine:()=>{}});
const state={mode:'play',options:[],selected:0,dialog:{},persistent:true,save_count:0,save_exists:false,sound:true};
window.emberwakeState(JSON.stringify(state));
const button=action=>actions.find(e=>e.dataset.action===action);const held=()=>{const set=new Set();for(const[a,p]of events)if(p)set.add(a);else set.delete(a);return set;};
let passed=0;function check(v,label){assert(v,label);passed++;console.log('PASS',label)}
elements['direction-pad'].fire('pointerdown',{pointerId:1,clientX:125,clientY:70});
button('jump').fire('pointerdown',{pointerId:2});
check(held().has('right')&&held().has('jump'),'independent fingers hold movement and jump');
button('jump').fire('pointerup',{pointerId:2});check(held().has('right')&&!held().has('jump'),'jump release preserves direction');
elements['direction-pad'].fire('pointermove',{pointerId:1,clientX:125,clientY:125});
button('dash').fire('pointerdown',{pointerId:3});check(['right','down','dash'].every(x=>held().has(x)),'diagonal drag plus dash supports breaker input');
button('dash').fire('pointercancel',{pointerId:3});check(!held().has('dash')&&held().has('down'),'pointer cancellation releases only its button');
button('attack').fire('pointerdown',{pointerId:4});button('attack').fire('pointerdown',{pointerId:5});button('attack').fire('pointerup',{pointerId:4});
check(held().has('attack'),'two fingers sharing a button do not release each other');
window.fire('blur');check(!held().size&&events.at(-1)[0]==='blur','window blur releases every finger and sends lifecycle save/pause');
button('heal').fire('pointerdown',{pointerId:6});document.hidden=true;document.fire('visibilitychange');check(!held().size,'backgrounding cancels hold-to-heal');
button('jump').fire('pointerdown',{pointerId:7});button('jump').fire('lostpointercapture',{pointerId:7});check(!held().size,'lost pointer capture cannot leave jump stuck');
window.emberwakeState(JSON.stringify({...state,mode:'pause',options:['继续旅途','辅助模式：关']}));
check(elements['touch-deck'].hidden&&!elements['menu-panel'].hidden&&elements['menu-options'].children.length===2,'pause exposes full-sized native menu options');
elements['menu-options'].children[0].fire('click');check(events.at(-1)[0]==='menu:0','HTML resume identifies one exact menu action');
let stopped=false;elements['menu-options'].children[0].fire('keydown',{stopPropagation(){stopped=true}});check(stopped,'HTML menu keyboard confirmation does not bubble into Godot');
let prevented=false;elements['menu-options'].children[0].fire('keydown',{key:'Enter',repeat:true,stopPropagation(){},preventDefault(){prevented=true}});check(prevented,'holding Enter cannot automatically confirm a newly opened new-game prompt');
const focusedButton=elements['menu-options'].children[1];focusedButton.focus();
window.emberwakeState(JSON.stringify({...state,mode:'pause',save_count:1,options:['继续旅途','辅助模式：关']}));
check(elements['menu-options'].children[1]===focusedButton&&document.activeElement===focusedButton,'save feedback keeps the same focused menu element');
window.emberwakeState(JSON.stringify({...state,mode:'pause',options:['继续旅途','辅助模式：开']}));
check(document.activeElement===elements['menu-options'].children[1],'changed setting restores keyboard focus to its option');
window.emberwakeState(JSON.stringify({...state,mode:'dialog',dialog:{title:'账册',text:'保留下来的名字'}}));
check(elements['reading-text'].textContent==='保留下来的名字'&&!elements['reading-panel'].hidden,'story text is readable in a separate phone panel');
window.emberwakeState(JSON.stringify({...state,persistent:false}));check(elements['save-status'].textContent.includes('可能丢失'),'nonpersistent storage warning is explicit');
window.emberwakeState(JSON.stringify({...state,save_error:'记录失败'}));check(elements['save-status'].textContent==='记录失败','save errors take precedence over optimistic feedback');
console.log('SHELL_INPUT_RESULT',passed,'passed');
