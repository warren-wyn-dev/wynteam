export type ReferenceProfile = {
  id: string;
  displayName: string;
  username: string;
  bio: string;
  website?: string;
  followingCount: string;
  followerCount: string;
};

export type ReferenceRelation = {
  displayName: string;
  username: string;
  actionLabel: string;
};

export const currentReferenceUser: ReferenceProfile = {
  id: "me",
  displayName: "พลอย เดินทาง",
  username: "ploy_journey",
  bio: "ชอบเที่ยว ชอบถ่ายรูป 📷 อยู่กรุงเทพฯ",
  website: "ployjourney.com",
  followingCount: "312",
  followerCount: "1.2K",
};

export const mindReferenceUser: ReferenceProfile = {
  id: "mind-coffee",
  displayName: "มายด์ กาแฟรัก",
  username: "mind_coffee",
  bio: "รีวิวร้านกาแฟทั่วกรุงเทพฯ ☕️",
  followingCount: "89",
  followerCount: "8.2K",
};

export const referenceFollowers: ReferenceRelation[] = [
  { displayName: "ต้น สายเทค", username: "@ton_tech", actionLabel: "ติดตามกลับ" },
];

export const referenceFollowing: ReferenceRelation[] = [
  { displayName: "มายด์ กาแฟรัก", username: "@mind_coffee", actionLabel: "กำลังติดตาม" },
];
