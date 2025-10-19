const pool = require("../config/database");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

exports.login = async (req, res) => {
    const { email, password } = req.body;

    if (email !== 'admin') {
        return res.status(403).json({ message: "관리자 계정이 아닙니다." });
    }

    try {
        const [users] = await pool.query("SELECT * FROM User WHERE email = ?", [email]);
        if (users.length === 0) {
            return res.status(401).json({ message: "이메일 또는 비밀번호가 올바르지 않습니다." });
        }

        const user = users[0];
        const isMatch = await bcrypt.compare(password, user.password);

        if (!isMatch) {
            return res.status(401).json({ message: "이메일 또는 비밀번호가 올바르지 않습니다." });
        }

        const accessToken = jwt.sign({ userId: user.user_id }, process.env.JWT_SECRET, { expiresIn: "1h" });
        res.status(200).json({ accessToken });

    } catch (error) {
        res.status(500).json({ message: "서버 오류가 발생했습니다." });
    }
};

async function getReportedUserId(targetType, targetId) {
    if (targetType === 'user') {
        return targetId;
    }
    if (targetType === 'post') {
        const [[post]] = await pool.query("SELECT user_id FROM Community_Post WHERE post_id = ?", [targetId]);
        return post ? post.user_id : null;
    }
    if (targetType === 'comment') {
        const [[comment]] = await pool.query("SELECT user_id FROM Community_Comment WHERE comment_id = ?", [targetId]);
        return comment ? comment.user_id : null;
    }
    return null;
}

exports.getReports = async (req, res) => {
    try {
        const [reports] = await pool.query(`
            SELECT 
                r.report_id, r.target_type, r.target_id, r.reason, r.screenshot_url, r.status, r.created_at,
                reporter.nickname as reporter_nickname
            FROM Report r
            JOIN User reporter ON r.reporter_id = reporter.user_id
            WHERE r.status = 'pending'
            ORDER BY r.created_at DESC
        `);

        for (const report of reports) {
            const reportedUserId = await getReportedUserId(report.target_type, report.target_id);
            if (reportedUserId) {
                const [[reportedUser]] = await pool.query("SELECT nickname FROM User WHERE user_id = ?", [reportedUserId]);
                report.reported_user_id = reportedUserId;
                report.reported_nickname = reportedUser ? reportedUser.nickname : '알 수 없음';
            }
        }
        
        res.status(200).json(reports);
    } catch (error) {
        console.error("신고 목록 조회 중 오류:", error);
        res.status(500).json({ message: "서버 오류로 신고 목록을 조회할 수 없습니다." });
    }
};

exports.processReport = async (req, res) => {
    const { reportId } = req.params;
    const { action, reportedUserId } = req.body;

    if (!action || !reportedUserId) {
        return res.status(400).json({ message: "필요한 정보가 누락되었습니다." });
    }

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        switch (action) {
            case 'dismiss':
                await connection.query("UPDATE Report SET status = 'dismissed' WHERE report_id = ?", [reportId]);
                break;
            case 'ban':
                await connection.query("UPDATE User SET banned_until = NOW() + INTERVAL 1 DAY WHERE user_id = ?", [reportedUserId]);
                await connection.query("UPDATE Report SET status = 'resolved' WHERE report_id = ?", [reportId]);
                break;
            case 'deactivate':
                await connection.query("DELETE FROM User WHERE user_id = ?", [reportedUserId]);
                await connection.query("UPDATE Report SET status = 'resolved' WHERE report_id = ?", [reportId]);
                break;
            default:
                await connection.rollback();
                return res.status(400).json({ message: "알 수 없는 조치입니다." });
        }

        await connection.commit();
        res.status(200).json({ message: "신고가 처리되었습니다." });
    } catch (error) {
        await connection.rollback();
        console.error("신고 처리 중 오류:", error);
        res.status(500).json({ message: "서버 오류로 신고를 처리할 수 없습니다." });
    } finally {
        connection.release();
    }
};

