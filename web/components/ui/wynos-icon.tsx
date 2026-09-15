import type { ComponentProps } from "react";
import {
  ArrowLeft,
  Heart,
  House,
  MessageCircle,
  Plus,
  Repeat2,
  UserRound,
  UsersRound,
} from "lucide-react";

const iconMap = {
  back: ArrowLeft,
  chat: MessageCircle,
  club: UsersRound,
  comment: MessageCircle,
  home: House,
  like: Heart,
  post: Plus,
  profile: UserRound,
  repost: Repeat2,
} as const;

export type WynosIconName = keyof typeof iconMap;

type WynosIconProps = Omit<ComponentProps<typeof House>, "name"> & {
  name: WynosIconName;
};

/**
 * Canonical icon wrapper for WYNOS web primitives.
 * Lucide icons are stroke-based and intentionally never opt into fill.
 */
export function WynosIcon({ name, size = 20, strokeWidth = 1.8, ...props }: WynosIconProps) {
  const Icon = iconMap[name];
  return <Icon aria-hidden="true" fill="none" size={size} strokeWidth={strokeWidth} {...props} />;
}
