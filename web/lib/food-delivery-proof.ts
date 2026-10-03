// food_delivery_proofs.order_id is unique, so PostgREST embeds it one-to-one
// as an object; older responses and fixtures use an array.
export function orderDeliveryProof<T>(order: { food_delivery_proofs?: T | T[] | null }): T | undefined {
  const proofs = order.food_delivery_proofs;
  return (Array.isArray(proofs) ? proofs[0] : proofs) ?? undefined;
}
