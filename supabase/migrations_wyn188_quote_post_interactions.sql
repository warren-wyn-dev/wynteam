-- Quote posts are distinct authored content (redrops.quote_text IS NOT NULL).
-- Engagement belongs to the quote, never to the embedded original Drop.
-- Run before deploying the quote action bar; every policy checks visibility
-- through redrops' existing RLS (including blocked accounts and hidden Drops).

CREATE TABLE IF NOT EXISTS public.quote_likes (
  quote_id uuid NOT NULL REFERENCES public.redrops(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (quote_id, user_id)
);
CREATE INDEX IF NOT EXISTS quote_likes_user_idx ON public.quote_likes(user_id);
ALTER TABLE public.quote_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Visible quote likes" ON public.quote_likes FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.redrops r WHERE r.id = quote_id AND r.quote_text IS NOT NULL));
CREATE POLICY "Like a visible quote as self" ON public.quote_likes FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id
  AND NOT internal.is_posting_blocked(auth.uid())
  AND EXISTS (SELECT 1 FROM public.redrops r WHERE r.id = quote_id AND r.quote_text IS NOT NULL));
CREATE POLICY "Unlike own quote likes" ON public.quote_likes FOR DELETE TO authenticated
USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.quote_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL REFERENCES public.redrops(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text_content text NOT NULL CHECK (char_length(btrim(text_content)) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS quote_comments_quote_created_idx
  ON public.quote_comments(quote_id, created_at ASC);
ALTER TABLE public.quote_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Visible quote comments" ON public.quote_comments FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.redrops r WHERE r.id = quote_id AND r.quote_text IS NOT NULL));
CREATE POLICY "Comment on a visible quote as self" ON public.quote_comments FOR INSERT TO authenticated
WITH CHECK (auth.uid() = author_id
  AND NOT internal.is_posting_blocked(auth.uid())
  AND EXISTS (SELECT 1 FROM public.redrops r WHERE r.id = quote_id AND r.quote_text IS NOT NULL));
CREATE POLICY "Delete own quote comments" ON public.quote_comments FOR DELETE TO authenticated
USING (auth.uid() = author_id);

CREATE TABLE IF NOT EXISTS public.quote_reposts (
  quote_id uuid NOT NULL REFERENCES public.redrops(id) ON DELETE CASCADE,
  reposter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (quote_id, reposter_id)
);
CREATE INDEX IF NOT EXISTS quote_reposts_reposter_created_idx
  ON public.quote_reposts(reposter_id, created_at DESC);
ALTER TABLE public.quote_reposts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Visible quote reposts" ON public.quote_reposts FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.redrops r WHERE r.id = quote_id AND r.quote_text IS NOT NULL));
CREATE POLICY "Repost a visible quote as self" ON public.quote_reposts FOR INSERT TO authenticated
WITH CHECK (auth.uid() = reposter_id
  AND NOT internal.is_posting_blocked(auth.uid())
  AND EXISTS (SELECT 1 FROM public.redrops r WHERE r.id = quote_id AND r.quote_text IS NOT NULL));
CREATE POLICY "Remove own quote reposts" ON public.quote_reposts FOR DELETE TO authenticated
USING (auth.uid() = reposter_id);

GRANT SELECT, INSERT, DELETE ON public.quote_likes, public.quote_comments, public.quote_reposts TO authenticated;
