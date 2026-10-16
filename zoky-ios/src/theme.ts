export const theme = {
  pink: "#F70365",
  pinkDark: "#CD0244",
  pinkLight: "#FCE0EC",
  pinkSoft: "#FFF5FA",
  ink: "#26222B",
  muted: "#706B75",
  border: "#F1E7EC",
  white: "#FFFFFF",
};

export function baht(amount: number): string {
  return "฿" + amount.toFixed(2).replace(/\.00$/, "");
}
