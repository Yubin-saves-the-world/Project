package com.asdf.board.be.community.service;

import com.asdf.board.be.community.dto.BlockPageDto;
import com.asdf.board.be.community.dto.BlockedUserDto;
import com.asdf.board.be.community.entity.Block;
import com.asdf.board.be.community.repository.BlockRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class BlockService {

    private final BlockRepository blockRepository;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;

    @Transactional
    public BlockedUserDto block(Long userId, Long blockedId) {
        accessGuard.requireOnboarded(userId);
        if (userId.equals(blockedId)) {
            throw new ApiException(ErrorCode.CANNOT_BLOCK_SELF);
        }
        User target = existing(blockedId);
        Block.Key key = new Block.Key();
        key.setBlockerId(userId);
        key.setBlockedId(blockedId);
        if (blockRepository.existsById(key)) {
            throw new ApiException(ErrorCode.ALREADY_BLOCKED);
        }
        Block saved = blockRepository.saveAndFlush(Block.builder()
                .blocker(userRepository.getReferenceById(userId)).blocked(target).build());
        return new BlockedUserDto(target.getId(), target.getNickname(), Times.offset(saved.getCreatedAt()));
    }

    @Transactional
    public void unblock(Long userId, Long blockedId) {
        accessGuard.requireOnboarded(userId);
        existing(blockedId);
        blockRepository.deleteOne(userId, blockedId);
    }

    @Transactional(readOnly = true)
    public BlockPageDto list(Long userId, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        Page<Block> result = blockRepository.findOfBlocker(userId, PageParams.of(page, pageSize, Sort.unsorted()));
        return new BlockPageDto(result.getContent().stream().map(b -> new BlockedUserDto(
                b.getBlocked().getId(), b.getBlocked().getNickname(), Times.offset(b.getCreatedAt()))).toList(),
                page, pageSize, (int) result.getTotalElements());
    }

    private User existing(Long id) {
        return userRepository.findById(id).filter(u -> u.getStatus() == User.Status.active)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
    }
}
