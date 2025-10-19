-- walking_mate 데이터베이스 초기화 및 전체 테이블 재생성 스크립트
-- 주의: 이 스크립트를 실행하면 기존의 모든 데이터가 삭제됩니다.

DROP DATABASE IF EXISTS walking_mate;
CREATE DATABASE walking_mate CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE walking_mate;

CREATE TABLE `User` (
    `user_id` INT AUTO_INCREMENT PRIMARY KEY,
    `email` VARCHAR(255) NOT NULL UNIQUE,
    `password` VARCHAR(255) NOT NULL,
    `nickname` VARCHAR(50) NOT NULL UNIQUE,
    `profile_image_url` VARCHAR(255),
    `points` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `location` VARCHAR(100),
    `discoverable` BOOLEAN DEFAULT TRUE,
    `refresh_token` VARCHAR(255) NULL,
    `banned_until` DATETIME NULL COMMENT '사용자 활동 정지 기한',
    `consecutive_walk_days` INT DEFAULT 0,
    `last_walk_date` DATE NULL
);

CREATE TABLE `Character` (
    `character_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `character_type` VARCHAR(50) NOT NULL DEFAULT 'polar_bear',
    `equipped_items` JSON,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);

CREATE TABLE `Item` (
    `item_id` INT AUTO_INCREMENT PRIMARY KEY,
    `item_name` VARCHAR(100) NOT NULL,
    `item_type` ENUM('head', 'wings', 'right_arm', 'body') NOT NULL,
    `description` TEXT,
    `price` INT NOT NULL,
    `image_url` VARCHAR(255) NOT NULL
);

CREATE TABLE `User_Item` (
    `user_item_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `item_id` INT NOT NULL,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    FOREIGN KEY (`item_id`) REFERENCES `Item`(`item_id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_user_item` (`user_id`, `item_id`)
);

CREATE TABLE `Walkway` (
    `walkway_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `title` VARCHAR(255) NOT NULL DEFAULT '새로운 AI 추천 산책로',
    `description` TEXT,
    `path_data` JSON,
    `distance` DOUBLE,
    `estimated_time` INT,
    `difficulty` ENUM('쉬움', '보통', '어려움'),
    `waypoints` JSON,
    `start_location_name` VARCHAR(255),
    `end_location_name` VARCHAR(255),
    `tags` JSON,
    `status` ENUM('public', 'private') NOT NULL DEFAULT 'private',
    `thumbnail_url` VARCHAR(255) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);

CREATE TABLE `Walk_Record` (
    `record_id` INT AUTO_INCREMENT PRIMARY KEY,
    `walkway_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `start_time` DATETIME NOT NULL,
    `end_time` DATETIME NOT NULL,
    `total_distance` DOUBLE,
    `review_content` TEXT,
    FOREIGN KEY (`walkway_id`) REFERENCES `Walkway`(`walkway_id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);

CREATE TABLE `Crew` (
    `crew_id` INT AUTO_INCREMENT PRIMARY KEY,
    `crew_name` VARCHAR(100) NOT NULL UNIQUE,
    `description` TEXT,
    `leader_id` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`leader_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);

CREATE TABLE `Crew_Member` (
    `crew_member_id` INT AUTO_INCREMENT PRIMARY KEY,
    `crew_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `role` ENUM('leader', 'member') DEFAULT 'member',
    `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`crew_id`) REFERENCES `Crew`(`crew_id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);

CREATE TABLE `Community_Post` (
    `post_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `crew_id` INT,
    `title` VARCHAR(255) NOT NULL,
    `content` TEXT NOT NULL,
    `image_url` VARCHAR(255),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    FOREIGN KEY (`crew_id`) REFERENCES `Crew`(`crew_id`) ON DELETE CASCADE
);

CREATE TABLE `Community_Comment` (
    `comment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `post_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `content` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`post_id`) REFERENCES `Community_Post`(`post_id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);

CREATE TABLE `Report` (
    `report_id` INT AUTO_INCREMENT PRIMARY KEY,
    `reporter_id` INT NOT NULL,
    `target_type` ENUM('post', 'comment', 'chat_message', 'user') NOT NULL,
    `target_id` VARCHAR(255) NOT NULL,
    `reason` TEXT,
    `screenshot_url` VARCHAR(255) NULL,
    `status` ENUM('pending', 'resolved', 'dismissed') NOT NULL DEFAULT 'pending',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`reporter_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
);


CREATE TABLE `Friendship` (
    `friendship_id` INT AUTO_INCREMENT PRIMARY KEY,
    `requester_id` INT NOT NULL,
    `receiver_id` INT NOT NULL,
    `status` ENUM('pending', 'accepted', 'rejected', 'blocked') NOT NULL DEFAULT 'pending',
    `chat_room_id` VARCHAR(255) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`requester_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    FOREIGN KEY (`receiver_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_friendship` (`requester_id`, `receiver_id`)
);

CREATE TABLE `Achievement` (
    `achievement_id` INT PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `category` VARCHAR(50),
    `goal` INT NOT NULL,
    `reward_points` INT DEFAULT 0,
    `icon_name` VARCHAR(100),
    `is_hidden` BOOLEAN DEFAULT FALSE
);

CREATE TABLE `User_Achievement` (
    `user_id` INT,
    `achievement_id` INT,
    `progress` INT DEFAULT 0,
    `status` ENUM('locked', 'in_progress', 'completed', 'rewarded') DEFAULT 'locked',
    `completed_at` TIMESTAMP NULL,
    PRIMARY KEY (user_id, achievement_id),
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    FOREIGN KEY (`achievement_id`) REFERENCES `Achievement`(`achievement_id`) ON DELETE CASCADE
);

CREATE TABLE `Point_Ledger` (
    `ledger_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT,
    `amount` INT NOT NULL,
    `description` VARCHAR(255),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE SET NULL
);

CREATE TABLE `All_Characters` (
    `character_id` VARCHAR(50) PRIMARY KEY,
    `character_name` VARCHAR(100) NOT NULL,
    `price` INT NOT NULL
);

CREATE TABLE `User_Character` (
    `user_character_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `character_id` VARCHAR(50) NOT NULL,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    FOREIGN KEY (`character_id`) REFERENCES `All_Characters`(`character_id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_user_character` (`user_id`, `character_id`)
);

CREATE TABLE `Walkway_Likes` (
    `like_id` INT AUTO_INCREMENT PRIMARY KEY,
    `walkway_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`walkway_id`) REFERENCES `Walkway`(`walkway_id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_like` (`walkway_id`, `user_id`)
);

CREATE TABLE `Community_Post_Likes` (
    `like_id` INT AUTO_INCREMENT PRIMARY KEY,
    `post_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`post_id`) REFERENCES `Community_Post`(`post_id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_like` (`post_id`, `user_id`)
);

CREATE TABLE `Sprite_Frame` (
    `frame_id` INT AUTO_INCREMENT PRIMARY KEY,
    `character_id` VARCHAR(50) NOT NULL,
    `animation_type` VARCHAR(50) NOT NULL,
    `frame_number` INT NOT NULL,
    `x` INT NOT NULL,
    `y` INT NOT NULL,
    `width` INT NOT NULL,
    `height` INT NOT NULL,
    FOREIGN KEY (`character_id`) REFERENCES `All_Characters`(`character_id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_frame` (`character_id`, `animation_type`, `frame_number`)
);
