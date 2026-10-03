import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./merchant.css";
const ICON=(size:number)=>`/merchant/icon-v11?size=${size}`;
export const metadata: Metadata = {
 title:"Wynos Merchant", applicationName:"Wynos Merchant",
 description:"จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
 manifest:"/merchant/manifest.webmanifest?v=20261004-11",
 icons:{
  icon:[16,32,48,192,512].map(size=>({url:ICON(size),sizes:`${size}x${size}`,type:"image/png"})),
  shortcut:[{url:ICON(32),sizes:"32x32",type:"image/png"}],
  apple:[57,72,76,114,120,152,167,180].map(size=>({url:ICON(size),sizes:`${size}x${size}`,type:"image/png"})),
  other:[{rel:"apple-touch-icon-precomposed",url:ICON(180),sizes:"180x180",type:"image/png"}],
 },
 openGraph:{title:"Wynos Merchant",description:"จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",images:[{url:ICON(512),width:512,height:512,alt:"Wynos Merchant"}],type:"website"},
 twitter:{card:"summary",title:"Wynos Merchant",description:"จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",images:[ICON(512)]},
 robots:{index:false,follow:false},
 appleWebApp:{capable:true,statusBarStyle:"default",title:"Wynos Merchant"},
 other:{"msapplication-TileColor":"#e32636","msapplication-TileImage":ICON(144)},
};
export const viewport: Viewport={width:"device-width",initialScale:1,maximumScale:1,userScalable:false,viewportFit:"cover",interactiveWidget:"resizes-content",themeColor:"#e32636"};
export default function MerchantLayout({children}:{children:ReactNode}){return children;}
