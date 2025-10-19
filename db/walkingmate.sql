-- walking_mate 데이터베이스 초기화 및 전체 테이블 재생성 스크립트
DROP DATABASE IF EXISTS walking_mate;
CREATE DATABASE walking_mate CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE walking_mate;

-- 테이블 생성 (CREATE TABLE)
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
CREATE TABLE `Walkway_Comment` (
    `comment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `walkway_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `content` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`walkway_id`) REFERENCES `Walkway`(`walkway_id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `User`(`user_id`) ON DELETE CASCADE
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

-- 데이터 삽입 (INSERT INTO)
INSERT INTO `Achievement` (`achievement_id`, `title`, `description`, `category`, `goal`, `reward_points`, `is_hidden`) VALUES
(100, '첫 걸음', '첫 산책 1회 완료', '산책', 1, 100, FALSE),
(101, '워밍업', '누적 1시간 산책', '산책', 60, 150, FALSE),
(102, '동네 한 바퀴', '누적 10km 걷기', '산책', 10, 200, FALSE),
(103, 'AI 맛보기', 'AI 추천 산책로 1회 이용', '산책', 1, 100, FALSE),
(104, '성실의 시작', '3일 연속 산책', '산책', 3, 300, FALSE),
(105, '걷기 전문가', '누적 50km 걷기', '산책', 50, 1000, FALSE),
(106, '시간 여행자', '누적 10시간 산책', '산책', 600, 1200, FALSE),
(107, 'AI 단짝', 'AI 추천 산책로 10회 이용', '산책', 10, 800, FALSE),
(108, '꾸준함의 힘', '14일 연속 산책', '산책', 14, 1500, FALSE),
(109, '주말의 정복자', '주말에만 누적 20km 걷기', '산책', 20, 700, FALSE),
(110, '지구 한 바퀴는 언제쯤?', '누적 500km 걷기', '산책', 500, 5000, FALSE),
(111, '산책의 달인', '누적 50시간 산책', '산책', 3000, 6000, FALSE),
(112, 'AI 탐험가', 'AI 추천 산책로 30회 이용', '산책', 30, 2500, FALSE),
(113, '한달의 약속', '30일 연속 산책', '산책', 30, 10000, FALSE),
(114, '마라토너', '한 번에 42.195km 이상 산책', '산책', 42, 15000, FALSE),
(200, '첫 워킹메이트', '첫 친구 1명 만들기', '소통', 1, 100, FALSE),
(201, '인기인', '친구 10명 만들기', '소통', 10, 500, FALSE),
(202, '마당발', '친구 50명 만들기', '소통', 50, 2000, FALSE),
(203, '새로운 시작', '크루 1개 가입하기', '소통', 1, 100, FALSE),
(204, '크루 활동가', '크루 5개 가입하기', '소통', 5, 500, FALSE),
(205, '내가 리더', '직접 크루 생성하기', '소통', 1, 300, FALSE),
(206, '첫 게시글', '게시글 1개 작성', '소통', 1, 50, FALSE),
(207, '첫 댓글', '댓글 1개 작성', '소통', 1, 30, FALSE),
(208, '커뮤니티 스타', '내가 쓴 글이 추천 10개 받기', '소통', 10, 500, FALSE),
(209, '소통의 달인', '게시글 20개, 댓글 50개 작성', '소통', 70, 1000, FALSE),
(300, '나의 첫 아이템', '상점에서 아이템 1회 구매', '성장', 1, 100, FALSE),
(301, '멋쟁이', '의상 아이템 10개 수집', '성장', 10, 500, FALSE),
(302, '풀 장착', '머리, 상의, 하의, 신발 모든 부위 아이템 착용', '성장', 4, 300, FALSE),
(303, '컬렉터', '모든 종류의 기본 아이템 수집', '성장', 20, 2000, FALSE),
(304, '첫 수익', '산책으로 포인트 첫 획득', '성장', 1, 50, FALSE),
(305, '티끌 모아 태산', '누적 10,000 포인트 획득', '성장', 10000, 500, FALSE),
(306, '저축왕', '한 번에 5,000 포인트 이상 보유', '성장', 5000, 1000, FALSE),
(307, '나만의 길', '산책로 1개 생성', '성장', 1, 200, FALSE),
(308, '인기 코스', '내가 만든 산책로가 추천 10개 받기', '성장', 10, 500, FALSE),
(309, '길 위의 탐험가', '다른 사람의 산책로 5회 이용', '성장', 5, 300, FALSE),
(900, '얼리버드', '새벽 5시 ~ 7시 사이에 산책 완료', '히든', 1, 300, TRUE),
(901, '올빼미', '밤 11시 ~ 새벽 1시 사이에 산책 완료', '히든', 1, 300, TRUE),
(902, '비가 오는 날엔', '비 오는 날씨에 산책 완료', '히든', 1, 500, TRUE),
(903, '생일 축하해!', '가입일(생일)에 산책 완료', '히든', 1, 1000, TRUE),
(904, '개발자를 찾아라', '앱 어딘가에 숨겨진 이스터에그 발견', '히든', 1, 777, TRUE);

INSERT INTO `Item` (`item_id`, `item_name`, `item_type`, `description`, `price`, `image_url`) VALUES
(101, '빨간 비니', 'head', '따뜻하고 포근한 빨간색 비니입니다.', 300, 'uploads/items/head_red_beanie.png'),
(201, '천사 날개', 'wings', '당신의 발걸음을 가볍게 만들어 줄 성스러운 날개.', 5000, 'uploads/items/wings_angel.png'),
(301, '별똥별 지팡이', 'right_arm', '휘두르면 밤하늘의 별똥별이 따라올 것 같은 신비로운 지팡이.', 1200, 'uploads/items/right_arm_star_wand.png'),
(401, '노란 우비', 'body', '비가 오는 날에도 산책을 즐길 수 있게 해주는 귀여운 우비.', 1500, 'uploads/items/body_yellow_raincoat.png');

INSERT INTO `All_Characters` (`character_id`, `character_name`, `price`) VALUES
('polar_bear', '북극곰', 0),
('shiba_inu', '시바견', 500);

INSERT INTO `Sprite_Frame` (`character_id`, `animation_type`, `frame_number`, `x`, `y`, `width`, `height`) VALUES
('polar_bear', 'dance', 1, 47, 39, 179, 208),
('polar_bear', 'dance', 2, 280, 39, 211, 203),
('polar_bear', 'dance', 3, 794, 798, 176, 202),
('polar_bear', 'dance', 4, 543, 546, 184, 204),
('polar_bear', 'run', 1, 294, 291, 174, 204),
('polar_bear', 'run', 2, 779, 44, 174, 202),
('polar_bear', 'run', 3, 536, 533, 173, 204),
('polar_bear', 'run', 4, 57, 778, 174, 201),
('shiba_inu', 'dance', 1, 45, 25, 196, 219),
('shiba_inu', 'dance', 2, 45, 277, 195, 217),
('shiba_inu', 'dance', 3, 534, 278, 191, 216),
('shiba_inu', 'dance', 4, 784, 277, 189, 216),
('shiba_inu', 'run', 1, 63, 38, 165, 215),
('shiba_inu', 'run', 2, 304, 38, 172, 215),
('shiba_inu', 'run', 3, 543, 38, 168, 214),
('shiba_inu', 'run', 4, 779, 38, 188, 213);