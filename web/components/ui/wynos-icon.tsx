import type { ComponentProps } from "react";
import { BarChart3,Bell,Camera,ChevronDown,ChevronLeft,Coffee,Heart,House,Image as ImageIcon,Link2,MapPin,Menu,MessageCircle,Mic,MoreHorizontal,PhoneOff,Plus,QrCode,Repeat2,Search,UserPlus,UserRound,UsersRound,Volume2,X } from "lucide-react";
const iconMap={back:ChevronLeft,camera:Camera,chat:MessageCircle,chevronDown:ChevronDown,club:UsersRound,close:X,coffee:Coffee,comment:MessageCircle,hangup:PhoneOff,home:House,image:ImageIcon,like:Heart,link:Link2,location:MapPin,menu:Menu,mic:Mic,more:MoreHorizontal,notifications:Bell,poll:BarChart3,post:Plus,profile:UserRound,qr:QrCode,repost:Repeat2,search:Search,userPlus:UserPlus,voice:Volume2} as const;
export type WynosIconName=keyof typeof iconMap;
type WynosIconProps=Omit<ComponentProps<typeof House>,"name">&{name:WynosIconName};
export function WynosIcon({name,size=20,strokeWidth=1.8,...props}:WynosIconProps){const Icon=iconMap[name];return <Icon aria-hidden="true" fill="none" size={size} strokeWidth={strokeWidth} {...props}/>}
