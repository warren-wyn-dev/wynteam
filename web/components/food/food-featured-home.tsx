"use client";

import { Bike, ChevronRight, Star, Ticket, UtensilsCrossed } from "lucide-react";

/** Public catalog and published merchant campaign data only. Never fabricate review scores,
 * delivery estimates, coupons, menu photos, or opening hours to match a visual mockup. */
export type FoodHomeFeatureDish = {
  id: string;
  name: string;
  price: number | string;
  imageUrl: string | null;
  available: boolean;
};

export type FoodHomeFeature = {
  name: string;
  coverUrl: string | null;
  deliveryFee: number | string | null;
  isOpen: boolean;
  rating?: number | null;
  ratingCount?: number | null;
  categories?: string[];
  eta?: string | null;
  promotion?: { label: string; condition: string | null } | null;
  isAd?: boolean;
  menu: FoodHomeFeatureDish[];
};

function money(amount: number | string): string | null {
  const n = Number(amount);
  return Number.isFinite(n) && n >= 0 ? `฿${new Intl.NumberFormat("th-TH", { maximumFractionDigits: 2 }).format(n)}` : null;
}

export function FoodFeaturedHome({
  feature,
  onStore,
  onMenu,
}: {
  feature: FoodHomeFeature;
  onStore: () => void;
  onMenu: (id: string) => void;
}) {
  const delivery = feature.deliveryFee === null ? null : money(feature.deliveryFee);
  const rating = Number(feature.rating);
  const showRating = Number.isFinite(rating) && rating > 0;
  const dishes = feature.menu.slice(0, 6);
  return (
    <div className="fx-featured-home">
      <button className="fx-featured-restaurant" type="button" onClick={onStore} aria-label={`ดูร้าน ${feature.name}`}>
        <span className="fx-featured-photo">
          {feature.coverUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={feature.coverUrl} alt="" loading="lazy" decoding="async" />
          ) : <UtensilsCrossed size={30} strokeWidth={1.5} />}
          {feature.isAd ? <span className="fx-featured-ad">โฆษณา</span> : null}
          {!feature.isOpen ? <span className="fx-featured-closed">ปิดอยู่</span> : null}
        </span>
        <span className="fx-featured-body">
          <span className="fx-featured-name">{feature.name}</span>
          {showRating || (feature.categories && feature.categories.length > 0) ? (
            <span className="fx-featured-meta">
              {showRating ? <><Star size={15} fill="#f5a623" strokeWidth={0} /><b>{rating.toFixed(1)}</b>{Number(feature.ratingCount) > 0 ? <span>({Number(feature.ratingCount).toLocaleString("th-TH")} รีวิว)</span> : null}</> : null}
              {feature.categories?.slice(0, 2).map(x => <span key={x}>{x}</span>)}
            </span>
          ) : null}
          {delivery !== null || feature.eta ? (
            <span className="fx-featured-delivery">
              <Bike size={19} strokeWidth={2} />
              {delivery !== null ? <strong>{delivery}</strong> : null}
              {feature.eta ? <span>{feature.eta}</span> : null}
            </span>
          ) : null}
          {feature.promotion ? (
            <span className="fx-featured-promo">
              <Ticket size={19} />
              <span><b>{feature.promotion.label}</b>{feature.promotion.condition ? <small>{feature.promotion.condition}</small> : null}</span>
              <ChevronRight size={17} />
            </span>
          ) : null}
          <span className="fx-featured-see">ดูร้านค้า <ChevronRight size={16} /></span>
        </span>
      </button>

      {dishes.length > 0 ? (
        <div className="fx-featured-dishes" aria-label="รายการอาหารของร้านที่แนะนำ">
          {dishes.map((dish) => {
            const price = money(dish.price);
            return (
              <button
                key={dish.id}
                type="button"
                className="fx-featured-dish"
                onClick={() => onMenu(dish.id)}
                disabled={!dish.available}
                aria-label={`ดูเมนู ${dish.name}${price ? ` ราคา ${price}` : ""}`}
              >
                <span className="fx-featured-dish-photo">
                  {dish.imageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={dish.imageUrl} alt="" loading="lazy" decoding="async" />
                  ) : <UtensilsCrossed size={23} strokeWidth={1.5} />}
                </span>
                <span className="fx-featured-dish-name">{dish.name}</span>
                <span className="fx-featured-dish-bottom">
                  {price ? <strong>{price}</strong> : null}
                  {dish.available ? <span className="fx-featured-plus" aria-hidden="true">+</span> : <small>สินค้าหมด</small>}
                </span>
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
