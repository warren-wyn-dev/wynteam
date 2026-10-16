export type OptionChoice = {
  id: string;
  name: string;
  price: number;
};

export type OptionGroup = {
  id: string;
  name: string;
  required: boolean;
  maxSelect: number;
  choices: OptionChoice[];
};

export type MenuItem = {
  id: string;
  storeId: string;
  category: string;
  name: string;
  description: string;
  price: number;
  available: boolean;
  options: OptionGroup[];
};

export type Store = {
  id: string;
  name: string;
  description: string;
  emoji: string;
  deliveryFee: number;
  open: boolean;
  menus: MenuItem[];
};

export type SelectedOption = {
  groupId: string;
  groupName: string;
  choiceId: string;
  choiceName: string;
  price: number;
};

export type CartLine = {
  key: string;
  storeId: string;
  itemId: string;
  name: string;
  basePrice: number;
  quantity: number;
  options: SelectedOption[];
};

export type Tab = "home" | "orders" | "messages" | "account";
export type HomePage = "hub" | "browse" | "store" | "cart";
