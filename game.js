(() => {
  'use strict';

  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d', { alpha: false });
  ctx.imageSmoothingEnabled = false;

  const W = canvas.width;
  const H = canvas.height;
  const TILE = 16;
  const MAP_W = 48;
  const MAP_H = 34;

  const C = {
    grass: '#6f9d4e', grass2: '#7eaa59', grassDark: '#557f3d', grassDeep: '#426b35',
    path: '#d9be7a', path2: '#c9a864', pathEdge: '#9d814a',
    water: '#66a7b7', water2: '#7cb9c4', waterDark: '#477d91',
    tree: '#315d37', tree2: '#447745', treeHi: '#5b8a4c', treeDark: '#24462e', trunk: '#765232',
    stone: '#87907b', stoneDark: '#5d6657', cream: '#f7edc7', ink: '#233127',
    roof: '#b85b4b', roofDark: '#783e3a', wall: '#e8d79e', wood: '#81593d',
    red: '#d04e44', redDark: '#843833', navy: '#31445e', skin: '#efc495',
    white: '#fff8dc'
  };

  const Tile = Object.freeze({ GRASS:0, PATH:1, WATER:2, TREE:3, TALL:4, FLOWER:5, ROCK:6, FENCE:7, HOUSE:8 });
  const map = Array.from({length: MAP_H}, () => Array(MAP_W).fill(Tile.GRASS));

  for (let y=0; y<MAP_H; y++) for (let x=0; x<MAP_W; x++) {
    if (x < 2 || x > MAP_W-3 || y < 2 || y > MAP_H-3) map[y][x] = Tile.TREE;
  }

  for (let y=2; y<MAP_H-2; y++) {
    const center = y < 11 ? 24 : y < 22 ? 23 : 25;
    for (let x=center-2; x<=center+2; x++) map[y][x] = Tile.PATH;
  }
  for (let x=23; x<39; x++) for (let y=9; y<=12; y++) map[y][x] = Tile.PATH;
  for (let x=10; x<=25; x++) for (let y=24; y<=27; y++) map[y][x] = Tile.PATH;

  for (let y=18; y<=25; y++) for (let x=34; x<=43; x++) {
    const edge = (x===34||x===43||y===18||y===25);
    if (!edge || ((x+y)%3!==0)) map[y][x] = Tile.WATER;
  }
  map[18][34]=map[18][43]=map[25][34]=map[25][43]=Tile.GRASS;

  const tallAreas = [
    [5,6,10,8], [9,15,8,6], [29,4,9,5], [29,13,7,4], [6,28,11,3], [29,28,12,3]
  ];
  for (const [sx,sy,ww,hh] of tallAreas) {
    for (let y=sy; y<sy+hh; y++) for (let x=sx; x<sx+ww; x++) {
      if (map[y][x] === Tile.GRASS) map[y][x] = Tile.TALL;
    }
  }

  [[5,18],[6,18],[5,19],[15,5],[16,5],[42,9],[41,9],[13,31],[14,31],[33,9]].forEach(([x,y])=>map[y][x]=Tile.TREE);
  [[18,18],[19,19],[7,23],[31,24],[42,27]].forEach(([x,y])=>map[y][x]=Tile.ROCK);
  [[4,5],[17,8],[18,8],[30,11],[31,11],[14,22],[15,22],[39,16],[40,16],[28,30]].forEach(([x,y])=>{
    if(map[y][x]===Tile.GRASS) map[y][x]=Tile.FLOWER;
  });
  for (let x=11; x<=18; x++) map[23][x] = Tile.FENCE;
  for (let y=4; y<=8; y++) for (let x=18; x<=23; x++) map[y][x] = Tile.HOUSE;
  map[9][21] = Tile.PATH;

  const solids = new Set([Tile.WATER, Tile.TREE, Tile.ROCK, Tile.FENCE, Tile.HOUSE]);

  const player = { x: 24*TILE+8, y: 28*TILE+8, speed: 58, dir: 'up', moving: false, step: 0 };
  const npc = { x: 31*TILE+8, y: 10*TILE+8, dir:'down', step:0 };
  const sign = { x: 22*TILE+8, y: 15*TILE+8 };
  const camera = { x:0, y:0 };
  const keys = new Set();
  let dialog = null;
  let areaTitle = 1.0;
  let time = 0;
  let last = performance.now();

  addEventListener('keydown', e => {
    const k = e.key.toLowerCase();
    if (['arrowup','arrowdown','arrowleft','arrowright',' ','e','w','a','s','d'].includes(k)) e.preventDefault();
    keys.add(k);
    if (!e.repeat && (k === 'e' || k === ' ')) interact();
    if (!e.repeat && dialog && (k === 'escape' || k === 'enter')) dialog = null;
  });
  addEventListener('keyup', e => keys.delete(e.key.toLowerCase()));

  function tileAtPixel(x,y) {
    const tx = Math.floor(x/TILE), ty = Math.floor(y/TILE);
    if (tx<0||ty<0||tx>=MAP_W||ty>=MAP_H) return Tile.TREE;
    return map[ty][tx];
  }

  function canStand(x,y) {
    const pts = [[x-4,y-3],[x+4,y-3],[x-4,y+6],[x+4,y+6]];
    return pts.every(([px,py]) => !solids.has(tileAtPixel(px,py)));
  }

  function dist(ax,ay,bx,by){ return Math.hypot(ax-bx, ay-by); }

  function interact() {
    if (dialog) { dialog = null; return; }
    const fx = player.x + (player.dir==='left'?-12:player.dir==='right'?12:0);
    const fy = player.y + (player.dir==='up'?-12:player.dir==='down'?12:0);
    if (dist(fx,fy,sign.x,sign.y) < 18) {
      dialog = { speaker:'', text:'HAINPFAD\nHainstadt  ←   →  Farnwald' };
      return;
    }
    if (dist(fx,fy,npc.x,npc.y) < 19) {
      dialog = { speaker:'Mira', text:'Im hohen Gras raschelt es heute ganz schön.\nZum Glück ist der Weg ruhig.' };
    }
  }

  function update(dt) {
    time += dt;
    areaTitle = Math.max(0, areaTitle - dt * .35);
    player.moving = false;
    if (dialog) return;

    let dx=0,dy=0;
    if (keys.has('a') || keys.has('arrowleft')) dx -= 1;
    if (keys.has('d') || keys.has('arrowright')) dx += 1;
    if (keys.has('w') || keys.has('arrowup')) dy -= 1;
    if (keys.has('s') || keys.has('arrowdown')) dy += 1;

    if (dx || dy) {
      player.moving = true;
      if (Math.abs(dx) > Math.abs(dy)) player.dir = dx < 0 ? 'left':'right';
      else player.dir = dy < 0 ? 'up':'down';
      const len = Math.hypot(dx,dy); dx/=len; dy/=len;
      const step = player.speed * dt;
      if (canStand(player.x+dx*step, player.y)) player.x += dx*step;
      if (canStand(player.x, player.y+dy*step)) player.y += dy*step;
      player.step += dt*9;
    }

    const maxX = MAP_W*TILE-W, maxY = MAP_H*TILE-H;
    const tx = Math.max(0, Math.min(maxX, player.x-W/2));
    const ty = Math.max(0, Math.min(maxY, player.y-H/2));
    camera.x += (tx-camera.x) * Math.min(1, dt*7);
    camera.y += (ty-camera.y) * Math.min(1, dt*7);
  }

  function pxRect(x,y,w,h,color){ ctx.fillStyle=color; ctx.fillRect(Math.round(x),Math.round(y),w,h); }

  function groundTile(x,y,tile) {
    const sx=x*TILE-camera.x, sy=y*TILE-camera.y;
    if (sx<-TILE||sy<-TILE||sx>W||sy>H) return;
    if (tile===Tile.PATH) {
      pxRect(sx,sy,TILE,TILE,C.path);
      if ((x*5+y*3)%7===0) pxRect(sx+3,sy+5,2,1,C.path2);
      if ((x+y)%11===0) pxRect(sx+11,sy+12,1,1,C.pathEdge);
      return;
    }
    if (tile===Tile.WATER) {
      pxRect(sx,sy,TILE,TILE,C.water);
      const off = Math.floor((time*6+x*3+y)%12);
      pxRect(sx+((off+2)%11),sy+5,5,1,C.water2);
      pxRect(sx+((off+7)%10),sy+11,4,1,C.waterDark);
      return;
    }
    pxRect(sx,sy,TILE,TILE,C.grass);
    if ((x*13+y*7)%9===0) pxRect(sx+3,sy+11,2,1,C.grass2);
    if ((x*3+y*11)%13===0) pxRect(sx+12,sy+4,1,2,C.grassDark);
    if (tile===Tile.FLOWER) drawFlowers(sx,sy,x+y);
  }

  function drawFlowers(sx,sy,seed){
    [[4,5],[10,9],[6,12]].forEach((p,i)=>{
      const white = (seed+i)%2===0 ? '#fff2cb' : '#e7d9ff';
      pxRect(sx+p[0],sy+p[1],1,1,white);
      pxRect(sx+p[0]+1,sy+p[1],1,1,'#e7aa59');
      pxRect(sx+p[0],sy+p[1]+1,1,1,C.grassDeep);
    });
  }

  function drawTallGrass(x,y,front=false){
    const sx=x*TILE-camera.x, sy=y*TILE-camera.y;
    const phase=Math.sin(time*2.2+x*.8+y*.4)*.6;
    const base = front ? sy+9 : sy+2;
    ctx.strokeStyle = front ? '#416c32' : '#527f3c';
    ctx.lineWidth=1;
    for(let i=0;i<5;i++){
      const xx=Math.round(sx+2+i*3);
      ctx.beginPath();
      ctx.moveTo(xx,base+5);
      ctx.lineTo(xx+(i%2?1:-1)+phase,base);
      ctx.stroke();
    }
    if(front) pxRect(sx,sy+13,TILE,3,'rgba(65,108,50,.20)');
  }

  function drawTree(x,y){
    const sx=x*TILE-camera.x, sy=y*TILE-camera.y;
    pxRect(sx+3,sy+12,11,3,'rgba(33,54,31,.18)');
    pxRect(sx+7,sy+10,3,6,C.trunk);
    pxRect(sx+2,sy+3,12,9,C.treeDark);
    pxRect(sx+1,sy+5,14,6,C.tree);
    pxRect(sx+4,sy+1,8,11,C.tree2);
    pxRect(sx+5,sy+2,4,2,C.treeHi);
    pxRect(sx+2,sy+6,3,2,C.treeHi);
    pxRect(sx+11,sy+5,2,2,C.treeDark);
  }

  function drawRock(x,y){
    const sx=x*TILE-camera.x, sy=y*TILE-camera.y;
    pxRect(sx+3,sy+10,11,3,'rgba(34,45,37,.18)');
    pxRect(sx+4,sy+6,9,6,C.stoneDark);
    pxRect(sx+5,sy+5,7,6,C.stone);
    pxRect(sx+6,sy+5,3,1,'#a9ae99');
  }

  function drawFence(x,y){
    const sx=x*TILE-camera.x, sy=y*TILE-camera.y;
    pxRect(sx,sy+7,16,3,C.wood);
    pxRect(sx+2,sy+4,3,9,'#9a714d');
    pxRect(sx+11,sy+4,3,9,'#9a714d');
    pxRect(sx+3,sy+5,1,1,'#c29a68');
  }

  function drawHouse(){
    const x=18*TILE-camera.x, y=4*TILE-camera.y;
    pxRect(x+1,y+37,94,16,'rgba(36,47,33,.18)');
    pxRect(x+7,y+24,82,45,C.wall);
    pxRect(x+11,y+29,74,36,'#f1e1ab');
    pxRect(x+2,y+12,92,23,C.roofDark);
    pxRect(x+7,y+7,82,25,C.roof);
    pxRect(x+13,y+3,70,8,'#ca6c56');
    pxRect(x+17,y+8,62,2,'#e28b6c');
    pxRect(x+8,y+54,80,3,C.wood);
    pxRect(x+17,y+39,15,13,C.navy); pxRect(x+19,y+41,11,9,'#86b6c2');
    pxRect(x+64,y+39,15,13,C.navy); pxRect(x+66,y+41,11,9,'#86b6c2');
    pxRect(x+43,y+43,13,22,C.wood); pxRect(x+46,y+46,7,19,'#5f4736');
    pxRect(x+52,y+55,2,2,'#d9bd70');
    pxRect(x+18,y+55,13,3,'#7b563b'); pxRect(x+65,y+55,13,3,'#7b563b');
    for(const ox of [20,24,28,67,71,75]) { pxRect(x+ox,y+54,1,2,'#4d773c'); pxRect(x+ox+1,y+53,1,1,'#f1d56e'); }
  }

  function drawSign(){
    const sx=sign.x-camera.x, sy=sign.y-camera.y;
    pxRect(sx-6,sy+5,12,3,'rgba(38,49,35,.18)');
    pxRect(sx-1,sy-1,3,11,C.wood);
    pxRect(sx-7,sy-8,15,9,'#b98d55');
    pxRect(sx-6,sy-7,13,7,'#d2a866');
    pxRect(sx-4,sy-5,8,1,'#7d5a38');
  }

  function drawCharacter(cx,cy,dir,step,kind='player'){
    const x=Math.round(cx-camera.x), y=Math.round(cy-camera.y);
    const bob = Math.sin(step*Math.PI)*0.6;
    const leg = Math.floor(step)%2;
    pxRect(x-5,y+6,10,3,'rgba(27,40,28,.24)');
    const isP = kind==='player';
    const main=isP?C.red:'#4770a0', dark=isP?C.redDark:'#304c70';
    if(dir==='left'||dir==='right'){
      pxRect(x-3+(leg?1:0),y+3,3,5,C.navy); pxRect(x+1-(leg?1:0),y+3,3,5,C.navy);
    } else {
      pxRect(x-4,y+3+(leg?1:0),3,5,C.navy); pxRect(x+1,y+3+(leg?0:1),3,5,C.navy);
    }
    pxRect(x-5,y-4+bob,10,9,dark); pxRect(x-4,y-5+bob,8,8,main);
    pxRect(x-4,y-11+bob,8,7,C.skin); pxRect(x-3,y-12+bob,6,2,'#4d3529');
    if(isP){
      pxRect(x-5,y-13+bob,10,3,C.redDark); pxRect(x-3,y-14+bob,7,2,C.red);
      if(dir==='right') pxRect(x+4,y-12+bob,3,1,C.red);
      if(dir==='left') pxRect(x-7,y-12+bob,3,1,C.red);
      if(dir==='left') pxRect(x+3,y-4+bob,3,6,'#6f5541');
      if(dir==='right') pxRect(x-6,y-4+bob,3,6,'#6f5541');
    } else {
      pxRect(x-4,y-13+bob,8,3,'#6b4938');
      pxRect(x-5,y-11+bob,2,4,'#6b4938');
      pxRect(x+3,y-11+bob,2,4,'#6b4938');
    }
    if(dir==='down'){ pxRect(x-2,y-9+bob,1,1,C.ink); pxRect(x+2,y-9+bob,1,1,C.ink); }
    if(dir==='left') pxRect(x-3,y-9+bob,1,1,C.ink);
    if(dir==='right') pxRect(x+3,y-9+bob,1,1,C.ink);
  }

  function drawWorld(){
    ctx.fillStyle=C.grass; ctx.fillRect(0,0,W,H);
    const x0=Math.max(0,Math.floor(camera.x/TILE)-1), x1=Math.min(MAP_W-1,Math.ceil((camera.x+W)/TILE)+1);
    const y0=Math.max(0,Math.floor(camera.y/TILE)-1), y1=Math.min(MAP_H-1,Math.ceil((camera.y+H)/TILE)+1);

    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++) groundTile(x,y,map[y][x]);

    ctx.globalAlpha=.35;
    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++) if(map[y][x]===Tile.PATH){
      const sx=x*TILE-camera.x, sy=y*TILE-camera.y;
      if(x>0 && map[y][x-1]!==Tile.PATH) pxRect(sx,sy,1,TILE,C.pathEdge);
      if(x<MAP_W-1 && map[y][x+1]!==Tile.PATH) pxRect(sx+15,sy,1,TILE,C.pathEdge);
    }
    ctx.globalAlpha=1;

    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++) if(map[y][x]===Tile.TALL) drawTallGrass(x,y,false);

    drawHouse();
    drawSign();

    const drawables=[];
    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){
      const t=map[y][x];
      if(t===Tile.TREE) drawables.push({y:y*TILE+15, fn:()=>drawTree(x,y)});
      if(t===Tile.ROCK) drawables.push({y:y*TILE+14, fn:()=>drawRock(x,y)});
      if(t===Tile.FENCE) drawables.push({y:y*TILE+12, fn:()=>drawFence(x,y)});
    }
    drawables.push({y:npc.y+8, fn:()=>drawCharacter(npc.x,npc.y,npc.dir,npc.step,'npc')});
    drawables.push({y:player.y+8, fn:()=>drawCharacter(player.x,player.y,player.dir,player.moving?player.step:0,'player')});
    drawables.sort((a,b)=>a.y-b.y).forEach(o=>o.fn());

    const ptx=Math.floor(player.x/TILE), pty=Math.floor((player.y+5)/TILE);
    for(let y=Math.max(y0,pty-1);y<=Math.min(y1,pty+1);y++) for(let x=Math.max(x0,ptx-1);x<=Math.min(x1,ptx+1);x++){
      if(map[y][x]===Tile.TALL && y*TILE+8 >= player.y-3) drawTallGrass(x,y,true);
    }
  }

  function roundRect(x,y,w,h,r,fill,stroke){
    ctx.beginPath(); ctx.roundRect(x,y,w,h,r); if(fill){ctx.fillStyle=fill;ctx.fill();} if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=1;ctx.stroke();}
  }

  function drawUI(){
    if(areaTitle>0){
      const a=Math.min(1,areaTitle*1.8);
      ctx.globalAlpha=a;
      roundRect(9,9,80,21,4,'rgba(22,35,26,.82)','rgba(247,237,199,.22)');
      ctx.fillStyle=C.white; ctx.font='bold 8px monospace'; ctx.fillText('HAINPFAD',16,18);
      ctx.fillStyle='#cbd5b8'; ctx.font='6px monospace'; ctx.fillText('zwischen Hainstadt & Farnwald',16,26);
      ctx.globalAlpha=1;
    }

    if(!dialog){
      const nearSign=dist(player.x,player.y,sign.x,sign.y)<28;
      const nearNpc=dist(player.x,player.y,npc.x,npc.y)<28;
      if(nearSign||nearNpc){
        roundRect(W-66,10,56,16,4,'rgba(22,35,26,.82)','rgba(247,237,199,.22)');
        ctx.fillStyle=C.white; ctx.font='7px monospace'; ctx.fillText('E  ansehen',W-57,20);
      }
    }

    if(dialog){
      const x=12,y=H-54,w=W-24,h=43;
      roundRect(x,y,w,h,5,'#f8efce','#25372d');
      roundRect(x+3,y+3,w-6,h-6,3,'#f8efce','#a38e63');
      ctx.fillStyle=C.ink;
      if(dialog.speaker){ ctx.font='bold 8px monospace'; ctx.fillText(dialog.speaker,22,y+13); }
      ctx.font='8px monospace';
      const lines=dialog.text.split('\n');
      lines.forEach((line,i)=>ctx.fillText(line,22,y+(dialog.speaker?25:17)+i*10));
      ctx.fillStyle='#79684b'; ctx.font='6px monospace'; ctx.fillText('E',W-25,H-17);
      ctx.fillStyle='#79684b'; ctx.beginPath(); ctx.moveTo(W-19,H-19); ctx.lineTo(W-15,H-19); ctx.lineTo(W-17,H-16); ctx.fill();
    }
  }

  function frame(now){
    const dt=Math.min(.033,(now-last)/1000); last=now;
    update(dt);
    drawWorld();
    drawUI();
    requestAnimationFrame(frame);
  }

  camera.x = Math.max(0, Math.min(MAP_W*TILE-W, player.x-W/2));
  camera.y = Math.max(0, Math.min(MAP_H*TILE-H, player.y-H/2));
  requestAnimationFrame(frame);
})();
