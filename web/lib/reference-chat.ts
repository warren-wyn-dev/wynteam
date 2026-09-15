export type ReferenceConversationStatus = "sent" | "read";

export type ReferenceConversation = {
  id: string;
  name: string;
  listTime: string;
  preview: string;
  unread: boolean;
  incomingText: string;
  outgoingText: string;
  messageTime: string;
  status: ReferenceConversationStatus;
};

export const referenceConversations: ReferenceConversation[] = [
  {
    id: "ton-tech",
    name: "ต้น สายเทค",
    listTime: "2 นาที",
    preview: "โอเคครับ เดี๋ยวส่งรูปให้ดู",
    unread: true,
    incomingText: "อยู่ตรงไหนอ่ะ อยากไปลองมั่ง 😍",
    outgoingText: "อยู่แถวทองหล่อเลย ซอย 5 นะ",
    messageTime: "10:26",
    status: "sent",
  },
  {
    id: "mind-coffee",
    name: "มายด์ กาแฟรัก",
    listTime: "1 ชม.",
    preview: "คุณ: ขอบคุณมากนะ 🙏",
    unread: false,
    incomingText: "ไว้มีร้านใหม่แล้วจะส่งมาให้อีกนะ ☕️",
    outgoingText: "ขอบคุณมากนะ 🙏",
    messageTime: "09:42",
    status: "read",
  },
];

export function getReferenceConversation(id: string) {
  return referenceConversations.find((conversation) => conversation.id === id);
}
