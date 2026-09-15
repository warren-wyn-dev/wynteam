export type ReferenceComment = {
  authorName: string;
  timeLabel: string;
  text: string;
};

export type ReferencePost = {
  id: string;
  authorName: string;
  username: string;
  timeLabel: string;
  text: string;
  detailText: string;
  liked: boolean;
  likeCount: number;
  commentCount: number;
  repostCount: number;
  comments: ReferenceComment[];
};

export const referencePosts: ReferencePost[] = [
  {
    id: "mind-coffee-001",
    authorName: "มายด์ กาแฟรัก",
    username: "@mind_coffee",
    timeLabel: "2 ชม.",
    text: "เพิ่งลองร้านกาแฟใหม่แถวบ้าน รสชาติดีเกินคาด แนะนำเลยถ้าใครผ่านแถวนี้",
    detailText: "เพิ่งลองร้านกาแฟใหม่แถวบ้าน รสชาติดีเกินคาด แนะนำเลยถ้าใครผ่านแถวนี้ ☕️",
    liked: true,
    likeCount: 48,
    commentCount: 12,
    repostCount: 3,
    comments: [
      {
        authorName: "ต้น สายเทค",
        timeLabel: "1 ชม.",
        text: "อยู่ตรงไหนอ่ะ อยากไปลองมั่ง 😍",
      },
    ],
  },
  {
    id: "ton-tech-002",
    authorName: "ต้น สายเทค",
    username: "@ton_tech",
    timeLabel: "5 ชม.",
    text: "ทริปทะเลเมื่อสุดสัปดาห์ ฟินมาก",
    detailText: "ทริปทะเลเมื่อสุดสัปดาห์ ฟินมาก",
    liked: false,
    likeCount: 21,
    commentCount: 5,
    repostCount: 1,
    comments: [],
  },
];

const referenceProfilePosts: ReferencePost[] = [
  {
    id: "ploy-profile-001",
    authorName: "พลอย เดินทาง",
    username: "@ploy_journey",
    timeLabel: "2 ชม.",
    text: "เพิ่งลองร้านกาแฟใหม่แถวบ้าน รสชาติดีเกินคาด",
    detailText: "เพิ่งลองร้านกาแฟใหม่แถวบ้าน รสชาติดีเกินคาด",
    liked: false,
    likeCount: 48,
    commentCount: 0,
    repostCount: 0,
    comments: [],
  },
  {
    id: "mind-profile-001",
    authorName: "มายด์ กาแฟรัก",
    username: "@mind_coffee",
    timeLabel: "1 วัน",
    text: "ร้านนี้บรรยากาศดีมาก เหมาะนั่งทำงาน",
    detailText: "ร้านนี้บรรยากาศดีมาก เหมาะนั่งทำงาน",
    liked: false,
    likeCount: 0,
    commentCount: 0,
    repostCount: 0,
    comments: [],
  },
];

export const trendingThailand = [
  "#ฝนตกกรุงเทพ",
  "ทีมชาติไทย",
  "#เชียงใหม่",
  "#Wynos",
] as const;

export function getReferencePost(postId: string) {
  return [...referencePosts, ...referenceProfilePosts].find((post) => post.id === postId) ?? null;
}
