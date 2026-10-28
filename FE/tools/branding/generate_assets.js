const fs=require('fs');
const path=require('path');
const sharp=require('sharp');
const root=path.resolve(__dirname,'../..');
const logo=path.join(root,'assets/branding/movid-start.png');
async function write(p, pipeline){fs.mkdirSync(path.dirname(path.join(root,p)),{recursive:true});await pipeline.toFile(path.join(root,p));}
async function padded(size, content){const inner=await sharp(logo).resize(content,content).png().toBuffer();return sharp({create:{width:size,height:size,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:inner,left:Math.round((size-content)/2),top:Math.round((size-content)/2)}]).png().toBuffer();}
(async()=>{
 await write('assets/branding/movid-app-icon.png',sharp(logo).flatten({background:'#FFFFFF'}).resize(1024,1024).removeAlpha().png());
 const contents=JSON.parse(fs.readFileSync(path.join(root,'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')));
 for(const item of contents.images){if(!item.filename)continue;const n=Math.round(parseFloat(item.size)*parseFloat(item.scale));await write('ios/Runner/Assets.xcassets/AppIcon.appiconset/'+item.filename,sharp(logo).flatten({background:'#FFFFFF'}).resize(n,n).removeAlpha().png());}
 for(const [folder,scale] of Object.entries({mdpi:1,hdpi:1.5,xhdpi:2,xxhdpi:3,xxxhdpi:4})){
  const size=Math.round(48*scale);
  await write(`android/app/src/main/res/mipmap-${folder}/ic_launcher.png`,sharp(logo).flatten({background:'#FFFFFF'}).resize(size,size).removeAlpha().png());
  await write(`android/app/src/main/res/mipmap-${folder}/ic_launcher_foreground.png`,sharp(await padded(Math.round(108*scale),Math.round(72*scale))));
  await write(`android/app/src/main/res/drawable-${folder}/movid_launch_logo.png`,sharp(logo).resize(Math.round(230*scale),Math.round(230*scale)).png());
  await write(`android/app/src/main/res/drawable-${folder}/movid_splash_android12.png`,sharp(await padded(Math.round(288*scale),Math.round(208*scale))));
 }
 for(const [suffix,scale] of [['',1],['@2x',2],['@3x',3]]){await write(`ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${suffix}.png`,sharp(logo).resize(230*scale,230*scale).png());}
 const wordmark=path.join(root,'assets/branding/movid-wordmark.png');
 for(const [suffix,scale] of [['',1],['@2x',2],['@3x',3]]){
  await write(`ios/Runner/Assets.xcassets/MOVIDWordmark.imageset/MOVIDWordmark${suffix}.png`,sharp(wordmark).resize(93*scale,39*scale).png());
 }
 for(const [folder,scale] of Object.entries({mdpi:1,hdpi:1.5,xhdpi:2,xxhdpi:3,xxxhdpi:4})){
  const w=Math.round(93*scale),h=Math.round(39*scale);
  const letters=await sharp(wordmark).resize(w,h).png().toBuffer();
  await write(`android/app/src/main/res/drawable-${folder}/movid_launch_wordmark.png`,sharp(letters));
  const sw=Math.round(200*scale),sh=Math.round(80*scale);
  await write(`android/app/src/main/res/drawable-${folder}/movid_splash_branding.png`,sharp({create:{width:sw,height:sh,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:letters,left:Math.round((sw-w)/2),top:Math.round((sh-h)/2)}]).png());
 }
 console.log('Generated opaque launcher icons, safe adaptive foregrounds, and native logo/wordmark resources.');
})().catch(e=>{console.error(e);process.exit(1)});
