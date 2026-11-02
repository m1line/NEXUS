CREATE TABLE IF NOT EXISTS users (
 id BIGSERIAL PRIMARY KEY, email TEXT NOT NULL UNIQUE, username TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL, display_name TEXT NOT NULL, avatar_emoji TEXT NOT NULL DEFAULT '👤',
 avatar_url TEXT, banner_url TEXT, bio TEXT NOT NULL DEFAULT '', role TEXT NOT NULL DEFAULT 'user'
 CHECK(role IN ('user','moderator','admin','owner')), is_private BOOLEAN NOT NULL DEFAULT FALSE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS banned_reason TEXT;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK(role IN ('user','moderator','admin','owner'));
CREATE TABLE IF NOT EXISTS follows (follower_id BIGINT REFERENCES users(id) ON DELETE CASCADE, followed_id BIGINT REFERENCES users(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY(follower_id,followed_id), CHECK(follower_id<>followed_id));
CREATE TABLE IF NOT EXISTS posts (id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, body TEXT NOT NULL DEFAULT '', media_url TEXT, media_type TEXT, clan_id BIGINT, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW(), CHECK(char_length(body)<=5000));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS media_duration INTEGER NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS likes (user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY(user_id,post_id));
CREATE TABLE IF NOT EXISTS bookmarks (user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY(user_id,post_id));
CREATE TABLE IF NOT EXISTS reposts (user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY(user_id,post_id));
CREATE TABLE IF NOT EXISTS comments (id BIGSERIAL PRIMARY KEY, post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, parent_id BIGINT REFERENCES comments(id) ON DELETE CASCADE, body TEXT NOT NULL CHECK(char_length(body) BETWEEN 1 AND 1500), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS clans (id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, tag TEXT NOT NULL UNIQUE, emoji TEXT NOT NULL DEFAULT '⚡', description TEXT NOT NULL DEFAULT '', owner_id BIGINT REFERENCES users(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS clan_members (clan_id BIGINT REFERENCES clans(id) ON DELETE CASCADE, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, role TEXT NOT NULL DEFAULT 'member', joined_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY(clan_id,user_id));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS clan_id BIGINT REFERENCES clans(id) ON DELETE SET NULL;
CREATE TABLE IF NOT EXISTS notifications (id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, actor_id BIGINT REFERENCES users(id) ON DELETE CASCADE, kind TEXT NOT NULL, post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE, body TEXT NOT NULL DEFAULT '', read_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS events (id BIGSERIAL PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', banner_url TEXT, starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ, created_by BIGINT REFERENCES users(id) ON DELETE SET NULL, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS event_members (event_id BIGINT REFERENCES events(id) ON DELETE CASCADE, user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, joined_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY(event_id,user_id));
CREATE TABLE IF NOT EXISTS reports (id BIGSERIAL PRIMARY KEY, reporter_id BIGINT REFERENCES users(id) ON DELETE CASCADE, post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE, target_user_id BIGINT REFERENCES users(id) ON DELETE CASCADE, reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS conversations (id BIGSERIAL PRIMARY KEY, user_a BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, user_b BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), CHECK(user_a<user_b), UNIQUE(user_a,user_b));
CREATE TABLE IF NOT EXISTS messages (id BIGSERIAL PRIMARY KEY, conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, body TEXT NOT NULL CHECK(char_length(body) BETWEEN 1 AND 4000), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), read_at TIMESTAMPTZ);
CREATE INDEX IF NOT EXISTS users_username_lower_idx ON users(LOWER(username));
CREATE INDEX IF NOT EXISTS posts_created_at_idx ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS messages_conversation_id_id_idx ON messages(conversation_id,id DESC);
CREATE INDEX IF NOT EXISTS notifications_user_created_idx ON notifications(user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS admin_audit_log (
 id BIGSERIAL PRIMARY KEY,
 actor_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
 action TEXT NOT NULL,
 target_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
 details JSONB NOT NULL DEFAULT '{}'::jsonb,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS admin_audit_created_idx ON admin_audit_log(created_at DESC);

CREATE TABLE IF NOT EXISTS stories (id BIGSERIAL PRIMARY KEY, user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, media_url TEXT NOT NULL, media_type TEXT NOT NULL CHECK(media_type IN ('image','video')), caption TEXT NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW()+INTERVAL '24 hours');
CREATE INDEX IF NOT EXISTS stories_expires_idx ON stories(expires_at);


-- NEXUS server channels and per-voice text chats
CREATE TABLE IF NOT EXISTS clan_channels (
 id BIGSERIAL PRIMARY KEY, clan_id BIGINT NOT NULL REFERENCES clans(id) ON DELETE CASCADE,
 name TEXT NOT NULL CHECK(char_length(name) BETWEEN 1 AND 40),
 channel_type TEXT NOT NULL CHECK(channel_type IN ('text','voice')),
 position INTEGER NOT NULL DEFAULT 0, created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(clan_id,name,channel_type)
);
CREATE TABLE IF NOT EXISTS clan_channel_messages (
 id BIGSERIAL PRIMARY KEY, channel_id BIGINT NOT NULL REFERENCES clan_channels(id) ON DELETE CASCADE,
 user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, body TEXT NOT NULL CHECK(char_length(body) BETWEEN 1 AND 2000),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS clan_channel_messages_idx ON clan_channel_messages(channel_id,id DESC);
INSERT INTO clan_channels(clan_id,name,channel_type,position) SELECT c.id,'общий','text',0 FROM clans c WHERE NOT EXISTS(SELECT 1 FROM clan_channels x WHERE x.clan_id=c.id AND x.channel_type='text');
INSERT INTO clan_channels(clan_id,name,channel_type,position) SELECT c.id,'голосовой','voice',1 FROM clans c WHERE NOT EXISTS(SELECT 1 FROM clan_channels x WHERE x.clan_id=c.id AND x.channel_type='voice');
