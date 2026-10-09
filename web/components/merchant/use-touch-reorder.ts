"use client";

import { useEffect, type RefObject } from "react";

type SortScope = "items" | "categories";
type TouchOrderCallback = (ids: string[], category?: string) => void;

/**
 * Native, non-passive Touch Events are required for Safari on iPhone.
 * Only active in the explicit sort mode, so regular feed scrolling is unchanged.
 */
export function useMerchantTouchDrag(
  rootRef: RefObject<HTMLDivElement | null>,
  active: boolean,
  scope: SortScope,
  renderVersion: number,
  onReordered: TouchOrderCallback,
) {
  useEffect(() => {
    const root = rootRef.current;
    if (!root || !active) return;

    type Drag = {
      identifier: number;
      source: HTMLElement;
      list: HTMLElement;
      category?: string;
      startX: number;
      startY: number;
      fingerOffsetY: number;
      visualRect: DOMRect;
      ghost: HTMLElement | null;
      changed: boolean;
    };
    let drag: Drag | null = null;

    const touchById = (touches: TouchList, id: number) => {
      for (let index = 0; index < touches.length; index += 1) {
        if (touches[index].identifier === id) return touches[index];
      }
      return null;
    };

    const clearDrag = () => {
      if (!drag) return;
      drag.ghost?.remove();
      drag.source.classList.remove("wm-touch-drag-source");
      drag = null;
    };

    const onTouchStart = (event: TouchEvent) => {
      if (drag || event.touches.length !== 1) return;
      const element = event.target instanceof Element ? event.target : null;
      if (!element) return;

      const head = element.closest<HTMLElement>(".wm-menu-category-heading");
      const row = element.closest<HTMLElement>(".wm-menu-row");
      const source = scope === "categories"
        ? head?.closest<HTMLElement>(".wm-menu-category")
        : row;
      if (!source || !root.contains(source)) return;

      const list = source.parentElement;
      if (!list || (scope === "items" && !list.classList.contains("wm-menu-list"))) return;
      if (scope === "categories" && !list.classList.contains("wm-menu-categories")) return;

      const touch = event.changedTouches[0];
      const visualRect = (scope === "categories" ? head : source)?.getBoundingClientRect();
      if (!touch || !visualRect) return;
      drag = {
        identifier: touch.identifier,
        source,
        list,
        category: scope === "items" ? source.closest<HTMLElement>("[data-wm-category]")?.dataset.wmCategory : undefined,
        startX: touch.clientX,
        startY: touch.clientY,
        fingerOffsetY: touch.clientY - visualRect.top,
        visualRect,
        ghost: null,
        changed: false,
      };
      if (event.cancelable) event.preventDefault();
    };

    const onTouchMove = (event: TouchEvent) => {
      if (!drag) return;
      const touch = touchById(event.touches, drag.identifier);
      if (!touch) return;
      if (event.cancelable) event.preventDefault();

      if (!drag.ghost) {
        if (Math.hypot(touch.clientX - drag.startX, touch.clientY - drag.startY) < 6) return;
        const preview = scope === "categories"
          ? drag.source.querySelector<HTMLElement>(".wm-menu-category-heading")
          : drag.source;
        if (!preview) return;
        const ghost = preview.cloneNode(true) as HTMLElement;
        ghost.classList.add("wm-touch-drag-ghost");
        Object.assign(ghost.style, {
          position: "fixed",
          left: `${drag.visualRect.left}px`,
          top: `${drag.visualRect.top}px`,
          width: `${drag.visualRect.width}px`,
          height: `${drag.visualRect.height}px`,
          pointerEvents: "none",
          zIndex: "99999",
        });
        document.body.appendChild(ghost);
        drag.source.classList.add("wm-touch-drag-source");
        drag.ghost = ghost;
      }

      drag.ghost.style.top = `${touch.clientY - drag.fingerOffsetY}px`;
      const remaining = Array.from(drag.list.children).filter(
        (node): node is HTMLElement => node instanceof HTMLElement && node !== drag!.source,
      );
      const before = remaining.find((node) => {
        const bounds = node.getBoundingClientRect();
        return touch.clientY < bounds.top + bounds.height / 2;
      }) ?? null;
      const priorNext = drag.source.nextElementSibling;
      drag.list.insertBefore(drag.source, before);
      if (drag.source.nextElementSibling !== priorNext) drag.changed = true;

      // Permit long lists to scroll while a row remains under the finger.
      if (touch.clientY < 88) window.scrollBy(0, -12);
      else if (touch.clientY > window.innerHeight - 105) window.scrollBy(0, 12);
    };

    const onTouchEnd = (event: TouchEvent) => {
      if (!drag || !touchById(event.changedTouches, drag.identifier)) return;
      const completed = drag;
      const changed = completed.changed;
      const ids = Array.from(completed.list.children)
        .filter((node): node is HTMLElement => node instanceof HTMLElement)
        .map((node) => scope === "categories" ? node.dataset.wmCategory : node.dataset.wmItem)
        .filter((id): id is string => Boolean(id));
      const category = completed.category;
      clearDrag();
      if (changed) onReordered(ids, category);
    };

    const onTouchCancel = () => {
      // Return to the original React ordering after an interrupted gesture.
      if (drag?.changed) {
        const ids = Array.from(drag.list.children)
          .filter((node): node is HTMLElement => node instanceof HTMLElement)
          .map((node) => scope === "categories" ? node.dataset.wmCategory : node.dataset.wmItem)
          .filter((id): id is string => Boolean(id));
        const category = drag.category;
        clearDrag();
        onReordered(ids, category);
      } else clearDrag();
    };

    root.addEventListener("touchstart", onTouchStart, { passive: false });
    window.addEventListener("touchmove", onTouchMove, { passive: false });
    window.addEventListener("touchend", onTouchEnd, { passive: false });
    window.addEventListener("touchcancel", onTouchCancel, { passive: false });
    return () => {
      root.removeEventListener("touchstart", onTouchStart);
      window.removeEventListener("touchmove", onTouchMove);
      window.removeEventListener("touchend", onTouchEnd);
      window.removeEventListener("touchcancel", onTouchCancel);
      clearDrag();
    };
  }, [rootRef, active, scope, renderVersion, onReordered]);
}
