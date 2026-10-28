package com.asdf.board.be.notification.repository;

import com.asdf.board.be.notification.entity.NotificationSetting;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationSettingRepository extends JpaRepository<NotificationSetting, NotificationSetting.Key> {
    List<NotificationSetting> findByIdUserId(Long userId);
}
