(async () => {
  try {
    if (figma.fileKey && figma.fileKey !== 'pdQ0Dn4jcL4m7FC0hXAQ7x') throw new Error('Wrong file');
    if (!figma.fileKey && figma.root.name !== '캡스톤') throw new Error('Wrong file');
    const page=figma.root.children.find(p=>p.id==='0:1');
    await figma.setCurrentPageAsync(page);
    const frames=page.children.filter(n=>n.type==='FRAME');
    const norm=s=>s.replace(/\s+/g,'');
    const wanted=[['login','00Login'],['signup','01회원가입'],['profile','02신체정보'],['analysis','03체형분석입력']];
    const files={}, screens=[], candidates=frames.map(n=>({id:n.id,name:n.name,x:n.x,y:n.y,w:n.width,h:n.height}));
    const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    for (const [key,name] of wanted) {
      const found=frames.filter(n=>norm(n.name)===name).sort((a,b)=>a.y-b.y||a.x-b.x);
      if (!found.length) throw new Error('Missing screen '+name);
      const frame=found[0], nodes=[], assets=[];
      files[key+'.png']=figma.base64Encode(await frame.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1}}));
      async function walk(n,parent) {
        const b=n.absoluteBoundingBox;
        const record={id:n.id,parent,name:n.name,type:n.type,visible:n.visible,opacity:n.opacity,x:b?b.x-frame.absoluteBoundingBox.x:0,y:b?b.y-frame.absoluteBoundingBox.y:0,width:n.width,height:n.height,transform:n.relativeTransform};
        for (const k of ['fills','strokes','strokeWeight','strokeAlign','cornerRadius','topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius','effects','clipsContent','blendMode']) if(k in n) record[k]=n[k];
        if(n.type==='TEXT') {
          record.text=n.characters;
          record.align=n.textAlignHorizontal;
          record.autoResize=n.textAutoResize;
          record.segments=n.getStyledTextSegments(['fontName','fontSize','letterSpacing','lineHeight','fills','textDecoration']);
        }
        const canAsset=['VECTOR','BOOLEAN_OPERATION','STAR','POLYGON'].includes(n.type) || (['GROUP','FRAME','INSTANCE'].includes(n.type)&&n.width<=64&&n.height<=64&&n.findAll(c=>c.type==='TEXT').length===0&&n.findAll(c=>c.type==='VECTOR').length>0);
        if(['681:31','681:33','681:39','681:41'].includes(n.id)) {
          files['figma-'+n.id.replace(':','_')+'.png']=figma.base64Encode(await n.exportAsync({format:'PNG',constraint:{type:'SCALE',value:8}}));
        }
        if(canAsset&&n.visible&&n.width>0&&n.height>0) {
          const filename='figma-'+n.id.replace(/[^a-zA-Z0-9]/g,'_')+'.svg';
          try {files[filename]=figma.base64Encode(await n.exportAsync({format:'SVG',svgOutlineText:false}));record.asset=filename;assets.push({id:n.id,file:filename,width:n.width,height:n.height});} catch(e){record.assetError=String(e);}
        }
        nodes.push(record);
        if('children' in n) for(const child of n.children) await walk(child,n.id);
      }
      for(const n of frame.children) await walk(n,frame.id);
      screens.push({key,id:frame.id,name:frame.name,width:frame.width,height:frame.height,fills:frame.fills,nodes,assets});
    }
    const design=JSON.parse(JSON.stringify({file:figma.root.name,page:page.name,candidates,screens},(k,v)=>typeof v==='symbol'?null:v));
    const response=await fetch('http://localhost:8766/export',{method:'POST',headers:{'Content-Type':'application/json','X-Export-Key':'LOCAL_EXPORT_KEY'},body:JSON.stringify({design,files})});
    if(!response.ok) throw new Error('Local export status '+response.status);
    figma.showUI('<html lang="ko"><meta charset="utf-8"><body style="font:14px system-ui;padding:20px"><h2>네 화면 원본 저장 완료</h2>'+screens.map(s=>'<p>'+esc(s.name)+' · '+s.width+'×'+s.height+' · '+s.nodes.length+'개 레이어 · '+s.assets.length+'개 SVG</p>').join('')+'<p>피그마 디자인은 수정하지 않았습니다.</p></body></html>',{width:520,height:320});
  } catch(error) {figma.showUI('<html><body><pre>'+String(error)+'</pre></body></html>',{width:520,height:320});}
})();