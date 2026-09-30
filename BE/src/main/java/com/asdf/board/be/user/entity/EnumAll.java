package com.asdf.board.be.user.entity;


public class EnumAll {

    public enum Provider {
        email, // 이메일로 회원가입
        google, // 구글로 간편로그인
        kakao; // 카카오로 간편로그인
    }


    public enum SurveyStatus {
        Pending, // 허용
        Rejected; // 거절
    }

    public enum Role {
        ADMIN, //관리자
        USER; // 사용자
    }

    public enum Gender {
        FEMALE, // 여성
        MALE; // 남성
    }

    public enum Goal {
        BULK,
        CUT,
        POSTURE;
    }

    public enum ExperienceLevel {
        BEGINNER,       // 운동 경험 거의 없음
        INTERMEDIATE,   // 어느 정도 해봄
        ADVANCED        // 꾸준히 해온 경험 많음
    }
}
