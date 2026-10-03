import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./merchant.css";
const I="/icons/merchant/v12";
export const metadata: Metadata={title:"Wynos Merchant",applicationName:"Wynos Merchant",description:"จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",manifest:"/merchant/manifest.webmanifest?v=12",icons:{icon:[{url:I+"-192.png",sizes:"192x192",type:"image/png"},{url:I+"-512.png",sizes:"512x512",type:"image/png"}],apple:[{url:I+"-180.png",sizes:"180x180",type:"image/png"}]},appleWebApp:{capable:true,statusBarStyle:"default",title:"Wynos Merchant"},robots:{index:false,follow:false}};
export const viewport:Viewport={width:"device-width",initialScale:1,maximumScale:1,userScalable:false,viewportFit:"cover",themeColor:"#ee1228"};
export default function MerchantLayout({children}:{children:ReactNode}){return children;}