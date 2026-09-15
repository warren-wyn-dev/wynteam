import type { ComponentProps } from "react";
import { BarChart3,Bell,Camera,ChevronLeft,Heart,House,Image as ImageIcon,MapPin,Menu,MessageCircle,MoreHorizontal,Plus,Repeat2,Search,UserPlus,UserRound,UsersRound,X } from "lucide-react";
const iconMap={back:ChevronLeft,camera:Camera,chat:MessageCircle,club:UsersRound,close:X,comment:MessageCircle,home:House,image:ImageIcon,like:Heart,location:MapPin,menu:Menu,more:MoreHorizontal,notifications:Bell,poll:BarChart3,post:Plus,profile:UserRound,repost:Repeat2,search:Search,userPlus:UserPlus} as const;
export type WynosIconName=keyof typeof iconMap;
type WynosIconProps=Omit<ComponentProps<typeof House>,"name">&{name:WynosIconName};
export function WynosIcon({name,size=20,strokeWidth=1.8,...props}:WynosIconProps){const Icon=iconMap[name];return <Icon aria-hidden="true" fill="none" size={size} strokeWidth={strokeWidth} {...props}/>}
