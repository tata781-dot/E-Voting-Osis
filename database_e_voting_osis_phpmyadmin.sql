-- Database E-Voting OSIS SMP IT AL HUDA
-- Kompatibel dengan MySQL/MariaDB untuk diimpor melalui phpMyAdmin.
-- Cara: buat database baru, pilih database tersebut, buka tab Import, pilih file ini.

CREATE TABLE IF NOT EXISTS candidates (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    candidate_number INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    vice_name VARCHAR(150) DEFAULT NULL,
    vision TEXT DEFAULT NULL,
    mission TEXT DEFAULT NULL,
    photo_url VARCHAR(500) DEFAULT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_candidates_number (candidate_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS voters (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    class_name VARCHAR(80) DEFAULT NULL,
    voter_type ENUM('siswa', 'guru') NOT NULL,
    token_hash CHAR(64) NOT NULL,
    has_voted TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_voters_token_hash (token_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS election_settings (
    id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    election_name VARCHAR(200) NOT NULL DEFAULT 'Pemilihan Ketua OSIS SMP IT AL HUDA',
    is_open TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT chk_election_settings_singleton CHECK (id = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO election_settings (id, election_name, is_open)
VALUES (1, 'Pemilihan Ketua OSIS SMP IT AL HUDA', 0)
ON DUPLICATE KEY UPDATE id = VALUES(id);

CREATE TABLE IF NOT EXISTS votes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    voter_id BIGINT UNSIGNED NOT NULL,
    candidate_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_votes_one_per_voter (voter_id),
    KEY idx_votes_candidate_id (candidate_id),
    CONSTRAINT fk_votes_voter
        FOREIGN KEY (voter_id) REFERENCES voters(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_votes_candidate
        FOREIGN KEY (candidate_id) REFERENCES candidates(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rekap suara. Hak akses harus tetap diatur di sisi aplikasi/server.
CREATE OR REPLACE VIEW vote_totals AS
SELECT
    c.id AS candidate_id,
    c.candidate_number,
    c.name,
    COUNT(v.id) AS total_votes
FROM candidates AS c
LEFT JOIN votes AS v ON v.candidate_id = c.id
GROUP BY c.id, c.candidate_number, c.name;

-- Fungsi PHP/backend harus:
-- 1. Memastikan election_settings.is_open = 1.
-- 2. Menghitung SHA-256 token yang dinormalisasi dengan trim + huruf besar.
-- 3. Memulai transaksi dan mengunci baris voter dengan SELECT ... FOR UPDATE.
-- 4. Memastikan token belum digunakan dan kandidat aktif.
-- 5. INSERT ke votes lalu UPDATE voters.has_voted = 1 dan COMMIT.
-- 6. Menolak token yang sudah digunakan; jangan mengandalkan validasi HTML saja.
--
-- Saat menambahkan pemilih, token_hash adalah SHA-256 dari token asli
-- setelah trim dan diubah ke huruf besar. Jangan menyimpan token asli di kolom ini.
-- Jangan menaruh kata sandi database di file HTML/JavaScript publik.
