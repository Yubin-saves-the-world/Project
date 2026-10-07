// Local, network-free Figma editing utility for the user-authorized capstone file.
(async () => {
  const expectedFile = 'pdQ0Dn4jcL4m7FC0hXAQ7x';
  const report = { ungrouped: [], backgrounds: [], skipped: [], moved: [], remaining: [], clipUnits: [], hiddenOverflow: [] };
  const escapeHtml = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function show(title, detail) {
    figma.showUI(`<html lang="ko"><meta charset="utf-8"><body style="font:14px/1.7 system-ui;padding:20px;color:#20251d"><h2>${escapeHtml(title)}</h2><pre style="white-space:pre-wrap">${escapeHtml(detail)}</pre></body></html>`, {width:520,height:520});
  }
  try {
    if (figma.fileKey && figma.fileKey !== expectedFile) throw new Error('캡스톤 파일에서만 실행할 수 있습니다.');
    if (!figma.fileKey && figma.root.name !== '캡스톤') throw new Error('캡스톤 파일에서만 실행할 수 있습니다.');
    const page = figma.root.children.find(p => p.id === '0:1');
    if (!page) throw new Error('대상 Page 1을 찾지 못했습니다.');
    await figma.setCurrentPageAsync(page);
    const screens = page.children.flatMap(n => n.type === 'SECTION' ? n.children.filter(c => c.type === 'FRAME') : n.type === 'FRAME' ? [n] : []);
    if (!screens.length) throw new Error('화면 프레임이 없어 변경하지 않았습니다.');
    const fonts = new Map();
    for (const screen of screens) {
      for (const text of screen.findAllWithCriteria({types:['TEXT']})) {
        for (const segment of text.getStyledTextSegments(['fontName'])) {
          fonts.set(JSON.stringify(segment.fontName), segment.fontName);
        }
      }
    }
    // Font failures occur before any canvas write.
    await Promise.all([...fonts.values()].map(font => figma.loadFontAsync(font)));
    const isContainer = node => node.type === 'GROUP' || node.type === 'FRAME';
    const hasPaint = paints => Array.isArray(paints) && paints.some(p => p.visible !== false && (p.opacity === undefined || p.opacity > 0));
    function canUnwrap(node) {
      if (node.isMask) return '마스크';
      if (node.children.some(c => c.isMask)) return '마스크 묶음';
      if (node.opacity !== 1) return '묶음 투명도';
      if (!['PASS_THROUGH','NORMAL'].includes(node.blendMode)) return '혼합 효과';
      if (node.type === 'GROUP' && node.effects.some(e => e.visible !== false)) return '그룹 효과';
      if (node.type === 'FRAME' && node.clipsContent) {
        if (node.name.endsWith(' · 표시영역') && node.children.length === 1) return '개별 요소의 표시영역';
        const t = node.absoluteTransform;
        if (Math.abs(t[0][0]-1)>.0001 || Math.abs(t[1][1]-1)>.0001 || Math.abs(t[0][1])>.0001 || Math.abs(t[1][0])>.0001) return '회전된 표시영역';
      }
      return null;
    }
    function background(node) {
      if (node.type !== 'FRAME') return;
      if (!hasPaint(node.fills) && !hasPaint(node.strokes) && !node.effects.some(e => e.visible !== false)) return;
      const rect = figma.createRectangle();
      rect.name = `${node.name} · 배경`;
      rect.resize(node.width, node.height);
      rect.fills = node.fills;
      rect.strokes = node.strokes;
      if (typeof node.strokeWeight === 'number') rect.strokeWeight = node.strokeWeight;
      for (const key of ['strokeTopWeight','strokeRightWeight','strokeBottomWeight','strokeLeftWeight']) {
        if (key in rect && typeof node[key] === 'number') rect[key] = node[key];
      }
      rect.strokeAlign = node.strokeAlign;
      rect.dashPattern = node.dashPattern;
      rect.effects = node.effects;
      rect.topLeftRadius = node.topLeftRadius;
      rect.topRightRadius = node.topRightRadius;
      rect.bottomLeftRadius = node.bottomLeftRadius;
      rect.bottomRightRadius = node.bottomRightRadius;
      rect.cornerSmoothing = node.cornerSmoothing;
      rect.visible = node.visible;
      node.insertChild(0, rect);
      rect.relativeTransform = [[1,0,0],[0,1,0]];
      report.backgrounds.push(rect.id);
    }
    function preserveClip(node) {
      if (node.type !== 'FRAME' || !node.clipsContent) return;
      const box = node.absoluteBoundingBox;
      if (!box) return;
      for (const child of [...node.children]) {
        if (!child.visible) continue;
        const b = child.absoluteBoundingBox;
        if (!b) continue;
        const x=Math.max(box.x,b.x), y=Math.max(box.y,b.y);
        const right=Math.min(box.x+box.width,b.x+b.width), bottom=Math.min(box.y+box.height,b.y+b.height);
        if (right<=x || bottom<=y) {
          child.visible=false;
          report.hiddenOverflow.push(child.id);
          continue;
        }
        if (b.x>=box.x-.1 && b.y>=box.y-.1 && b.x+b.width<=box.x+box.width+.1 && b.y+b.height<=box.y+box.height+.1) continue;
        const clip=figma.createFrame();
        clip.name=child.name+' · 표시영역';
        clip.resize(right-x,bottom-y);
        clip.fills=[];
        clip.clipsContent=true;
        const index=node.children.indexOf(child), transform=child.relativeTransform;
        node.insertChild(index,clip);
        clip.x=x-box.x;
        clip.y=y-box.y;
        clip.appendChild(child);
        child.relativeTransform=[[transform[0][0],transform[0][1],transform[0][2]-clip.x],[transform[1][0],transform[1][1],transform[1][2]-clip.y]];
        report.clipUnits.push(clip.id);
      }
    }
    function unwrapChildren(parent) {
      for (const node of [...parent.children]) {
        if (!isContainer(node)) continue;
        // Components, instances and boolean/vector art remain editable as units.
        const reason = canUnwrap(node);
        if (reason) { report.skipped.push({id:node.id,name:node.name,reason}); continue; }
        if (node.type === 'FRAME' && node.layoutMode !== 'NONE') {
          const positions = node.children.map(c => ({c, transform:c.relativeTransform}));
          node.layoutMode = 'NONE';
          for (const p of positions) p.c.relativeTransform = p.transform;
        }
        unwrapChildren(node);
        preserveClip(node);
        const id = node.id, name = node.name;
        const locked = node.locked, hidden = !node.visible;
        if (locked) node.locked = false;
        background(node);
        for (const child of node.children) {
          if (hidden) child.visible = false;
          if (locked) child.locked = true;
        }
        const children = figma.ungroup(node);
        report.moved.push(...children.map(c => c.id));
        report.ungrouped.push({id,name});
      }
    }
    for (const screen of screens) unwrapChildren(screen);
    for (const screen of screens) report.remaining.push(...screen.findAll(n => {
      if (!isContainer(n)) return false;
      if (n.type==='FRAME' && n.clipsContent && n.children.length===1 && n.name.endsWith(' · 표시영역')) return false;
      for (let parent=n.parent; parent && parent!==screen; parent=parent.parent) {
        if (['INSTANCE','COMPONENT','COMPONENT_SET'].includes(parent.type)) return false;
      }
      return true;
    }).map(n => ({id:n.id,name:n.name})));
    figma.currentPage.selection = screens;
    show('내부 묶음 해제 결과', JSON.stringify({screens:screens.length,ungrouped:report.ungrouped.length,backgrounds:report.backgrounds.length,clipUnits:report.clipUnits.length,hiddenOverflow:report.hiddenOverflow.length,remaining:report.remaining.length,skipped:report.skipped.filter(s=>s.reason!=='개별 요소의 표시영역')},null,2));
  } catch (error) {
    show('변경 중단 · 현재 상태 확인 필요', JSON.stringify({error:String(error),ungrouped:report.ungrouped.length,backgrounds:report.backgrounds.length,skipped:report.skipped},null,2));
  }
})();
