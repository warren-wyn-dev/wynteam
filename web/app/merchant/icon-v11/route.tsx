import { ImageResponse } from "next/og";

const ALLOWED_SIZES = new Set([16,32,48,57,64,72,76,96,114,120,128,144,152,167,180,192,256,384,512]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const requested = Number(searchParams.get("size") ?? "180");
  const size = ALLOWED_SIZES.has(requested) ? requested : 180;
  const s = size / 512;
  return new ImageResponse(
    <div style={{
      width:"100%",height:"100%",display:"flex",alignItems:"center",justifyContent:"center",
      background:"linear-gradient(145deg,#ff2b38 0%,#f60019 48%,#d90012 100%)",
      borderRadius:Math.round(96*s),position:"relative",overflow:"hidden",
      boxShadow:"inset 0 0 0 "+Math.max(2,Math.round(7*s))+"px rgba(255,255,255,.28)"
    }}>
      <div style={{position:"absolute",left:Math.round(22*s),top:Math.round(12*s),width:Math.round(300*s),height:Math.round(105*s),borderRadius:"50%",background:"rgba(255,255,255,.20)",filter:"blur("+Math.max(3,Math.round(16*s))+"px)"}} />
      <svg width={Math.round(420*s)} height={Math.round(360*s)} viewBox="0 0 420 360" style={{filter:"drop-shadow(0 10px 7px rgba(90,0,0,.38))"}}>
        <path d="M38 82 L112 206 L205 72 L300 206 L382 82" fill="none" stroke="#fff7f7" strokeWidth="42" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M210 137 L111 258 L111 318 L309 318 L309 258 Z" fill="#fff8f8" stroke="#ffdede" strokeWidth="5" strokeLinejoin="round"/>
        <path d="M142 205 H278 V252 C278 276 258 291 238 291 H182 C160 291 142 275 142 252 Z" fill="#fff"/>
        <path d="M142 205 H278 L264 249 C259 266 239 267 230 251 C221 269 198 269 190 251 C181 268 159 267 154 249 Z" fill="#f21b2e"/>
        <path d="M142 205 H278 L268 239 H152 Z" fill="#fff"/>
        <path d="M169 205 H196 L191 252 C184 267 163 263 158 249 Z" fill="#f21b2e"/>
        <path d="M224 205 H251 L262 249 C257 264 236 268 229 252 Z" fill="#f21b2e"/>
        <rect x="188" y="266" width="44" height="52" rx="8" fill="#e70d20"/>
      </svg>
    </div>,
    { width:size, height:size, headers:{ "Cache-Control":"public, max-age=31536000, immutable" } }
  );
}
