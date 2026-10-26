package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.asdf.board.be.support.TestImages;
import com.asdf.board.be.user.entity.User;
import com.jayway.jsonpath.JsonPath;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder;

class CommunityApiTest extends ApiTestBase {

    private MockMultipartFile image(long seed) {
        return new MockMultipartFile("images", "a.jpg", "image/jpeg", TestImages.jpeg(seed));
    }

    private ResultActions createPost(TestUser user, String category, String title, String content, MockMultipartFile... files)
            throws Exception {
        MockMultipartHttpServletRequestBuilder b = multipart("/api/posts");
        for (MockMultipartFile f : files) {
            b.file(f);
        }
        return mvc.perform(b.param("category", category).param("title", title).param("content", content)
                .header("Authorization", "Bearer " + user.token()));
    }

    private long newPost(TestUser user, String category, String title) throws Exception {
        return readId(createPost(user, category, title, "본문 " + title).andExpect(status().isCreated()), "$.post_id");
    }

    private ResultActions patchPost(TestUser user, long postId, String[][] params, MockMultipartFile... files) throws Exception {
        MockMultipartHttpServletRequestBuilder b = multipart(HttpMethod.PATCH, "/api/posts/" + postId);
        for (MockMultipartFile f : files) {
            b.file(f);
        }
        for (String[] p : params) {
            b.param(p[0], p[1]);
        }
        return mvc.perform(b.header("Authorization", "Bearer " + user.token()));
    }

    private TestUser admin() throws Exception {
        TestUser user = newUser(true);
        User entity = userRepository.findById(user.id()).orElseThrow();
        entity.setRole(User.Role.admin);
        userRepository.saveAndFlush(entity);
        return user;
    }

    @Test
    void createsAndReadsPostWithImages() throws Exception {
        TestUser user = newUser(true);
        String content = "가".repeat(150);
        ResultActions created = createPost(user, "info", "제목", content, image(1), image(2))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.category").value("info"))
                .andExpect(jsonPath("$.title").value("제목"))
                .andExpect(jsonPath("$.content").value(content))
                .andExpect(jsonPath("$.content_preview").value("가".repeat(100)))
                .andExpect(jsonPath("$.images.length()").value(2))
                .andExpect(jsonPath("$.thumbnail_url").isNotEmpty())
                .andExpect(jsonPath("$.is_mine").value(true))
                .andExpect(jsonPath("$.liked_by_me").value(false))
                .andExpect(jsonPath("$.updated_at").doesNotExist())
                .andExpect(jsonPath("$.is_pinned").value(false))
                .andExpect(jsonPath("$.view_count").value(0))
                .andExpect(jsonPath("$.author.user_id").value(user.id()));
        long id = readId(created, "$.post_id");
        String url = read(getAs(user, "/api/posts/" + id), "$.images[0].url");
        String path = url.substring(url.indexOf("/api/files/"));
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(path)).andExpect(status().isOk());

        getAs(newUser(true), "/api/posts/" + id).andExpect(status().isOk())
                .andExpect(jsonPath("$.view_count").value(2)).andExpect(jsonPath("$.is_mine").value(false));
        getAs(user, "/api/posts/999999").andExpect(status().isNotFound());
    }

    @Test
    void validatesPostInput() throws Exception {
        TestUser user = newUser(true);
        createPost(user, "info", " ", "본문").andExpect(status().isBadRequest());
        createPost(user, "info", "가".repeat(51), "본문").andExpect(status().isBadRequest());
        createPost(user, "info", "제목", "가".repeat(2001)).andExpect(status().isBadRequest());
        createPost(user, "bogus", "제목", "본문").andExpect(status().isBadRequest());
        createPost(user, "info", "제목", "본문", image(1), image(2), image(3), image(4), image(5))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("IMAGE_LIMIT_EXCEEDED"));
        createPost(user, "info", "제목", "본문", new MockMultipartFile("images", "a.txt", "text/plain", "hello".getBytes()))
                .andExpect(status().isUnsupportedMediaType()).andExpect(jsonPath("$.code").value("IMAGE_INVALID_TYPE"));
        createPost(user, "info", "제목", "본문", new MockMultipartFile("images", "a.jpg", "image/jpeg", new byte[11 * 1024 * 1024]))
                .andExpect(status().isPayloadTooLarge());
        createPost(user, "notice", "공지", "본문")
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("NOTICE_ADMIN_ONLY"));
        createPost(newUser(false), "info", "제목", "본문").andExpect(status().isForbidden());
        mvc.perform(multipart("/api/posts").param("category", "info").param("title", "t").param("content", "c"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void listPinsNoticesFiltersAndPages() throws Exception {
        TestUser admin = admin();
        TestUser user = newUser(true);
        long first = newPost(user, "info", "첫째");
        long question = newPost(user, "question", "질문");
        long notice = readId(createPost(admin, "notice", "공지", "내용").andExpect(status().isCreated())
                .andExpect(jsonPath("$.is_pinned").value(true)), "$.post_id");
        long last = newPost(user, "info", "마지막");

        String all = getAs(user, "/api/posts").andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        List<Integer> ids = JsonPath.read(all, "$.items[*].post_id");
        assertThat(ids.subList(0, 4)).containsExactly((int) notice, (int) last, (int) question, (int) first);
        getAs(user, "/api/posts?category=question").andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.total").value(1));
        getAs(user, "/api/posts?page=2&page_size=2").andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.page").value(2)).andExpect(jsonPath("$.page_size").value(2));
        getAs(user, "/api/posts?page=0").andExpect(status().isBadRequest());
        getAs(user, "/api/posts?page_size=51").andExpect(status().isBadRequest());
        getAs(user, "/api/posts?category=bogus").andExpect(status().isBadRequest());
        getAs(newUser(false), "/api/posts").andExpect(status().isForbidden());
    }

    @Test
    void patchEditsOnlyOwnPostAndManagesImages() throws Exception {
        TestUser user = newUser(true);
        long id = readId(createPost(user, "info", "원본", "본문", image(1), image(2), image(3)).andExpect(status().isCreated()), "$.post_id");
        long firstImage = readId(getAs(user, "/api/posts/" + id), "$.images[0].image_id");

        patchPost(user, id, new String[][]{}).andExpect(status().isBadRequest());
        patchPost(user, id, new String[][]{{"title", "새 제목"}}).andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("새 제목")).andExpect(jsonPath("$.content").value("본문"))
                .andExpect(jsonPath("$.images.length()").value(3)).andExpect(jsonPath("$.updated_at").isNotEmpty());
        patchPost(user, id, new String[][]{}, image(4), image(5))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("IMAGE_LIMIT_EXCEEDED"));
        patchPost(user, id, new String[][]{{"remove_image_ids", "999999"}}).andExpect(status().isBadRequest());
        patchPost(user, id, new String[][]{{"remove_image_ids", String.valueOf(firstImage)}}, image(4), image(5))
                .andExpect(status().isOk()).andExpect(jsonPath("$.images.length()").value(4));
        patchPost(user, id, new String[][]{{"category", "notice"}})
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("NOTICE_ADMIN_ONLY"));
        patchPost(user, id, new String[][]{{"title", ""}}).andExpect(status().isBadRequest());
        patchPost(newUser(true), id, new String[][]{{"title", "남의 글"}}).andExpect(status().isForbidden());
        patchPost(user, 999999, new String[][]{{"title", "x"}}).andExpect(status().isNotFound());
    }

    @Test
    void deleteRemovesEverythingAndAdminMayDeleteOthers() throws Exception {
        TestUser admin = admin();
        TestUser user = newUser(true);
        TestUser other = newUser(true);
        long id = readId(createPost(user, "info", "삭제", "본문", image(1)).andExpect(status().isCreated()), "$.post_id");
        postAs(other, "/api/posts/" + id + "/likes", null).andExpect(status().isOk());
        long comment = readId(postAs(other, "/api/posts/" + id + "/comments", "{\"content\":\"댓글\"}")
                .andExpect(status().isCreated()), "$.comment_id");
        postAs(other, "/api/posts/" + id + "/comments", "{\"content\":\"대댓글\",\"parent_id\":" + comment + "}")
                .andExpect(status().isCreated());
        postAs(newUser(true), "/api/reports", "{\"target_type\":\"post\",\"target_id\":" + id + ",\"reason\":\"spam\"}")
                .andExpect(status().isCreated());

        deleteAs(other, "/api/posts/" + id).andExpect(status().isForbidden());
        deleteAs(admin, "/api/posts/" + id).andExpect(status().isNoContent());
        getAs(user, "/api/posts/" + id).andExpect(status().isNotFound());
        deleteAs(user, "/api/posts/" + id).andExpect(status().isNotFound());

        long own = newPost(user, "info", "내 글");
        deleteAs(user, "/api/posts/" + own).andExpect(status().isNoContent());
    }

    @Test
    void commentsSupportRepliesAndSoftDelete() throws Exception {
        TestUser author = newUser(true);
        TestUser reader = newUser(true);
        long post = newPost(author, "info", "댓글글");
        String base = "/api/posts/" + post + "/comments";

        long root = readId(postAs(reader, base, "{\"content\":\"첫 댓글\"}").andExpect(status().isCreated())
                .andExpect(jsonPath("$.parent_id").doesNotExist()).andExpect(jsonPath("$.is_mine").value(true))
                .andExpect(jsonPath("$.is_deleted").value(false)), "$.comment_id");
        long reply = readId(postAs(author, base, "{\"content\":\"답글\",\"parent_id\":" + root + "}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.parent_id").value(root)), "$.comment_id");
        postAs(reader, base, "{\"content\":\"답글의 답글\",\"parent_id\":" + reply + "}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.parent_id").value(root));
        long second = readId(postAs(reader, base, "{\"content\":\"두번째\"}").andExpect(status().isCreated()), "$.comment_id");
        postAs(reader, base, "{\"content\":\"\"}").andExpect(status().isBadRequest());
        postAs(reader, base, "{\"content\":\"" + "가".repeat(501) + "\"}").andExpect(status().isBadRequest());
        postAs(reader, base, "{\"content\":\"x\",\"parent_id\":999999}").andExpect(status().isBadRequest());
        long otherPost = newPost(author, "info", "다른글");
        postAs(reader, "/api/posts/" + otherPost + "/comments", "{\"content\":\"x\",\"parent_id\":" + root + "}")
                .andExpect(status().isBadRequest());
        postAs(reader, "/api/posts/999999/comments", "{\"content\":\"x\"}").andExpect(status().isNotFound());

        getAs(author, "/api/posts/" + post).andExpect(jsonPath("$.comment_count").value(4));
        String list = getAs(author, base).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        List<String> contents = JsonPath.read(list, "$.items[*].content");
        assertThat(contents).containsExactly("첫 댓글", "답글", "답글의 답글", "두번째");
        getAs(author, base + "?page=2&page_size=3").andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.total").value(4));

        deleteAs(author, base + "/" + root).andExpect(status().isForbidden());
        deleteAs(reader, base + "/" + root).andExpect(status().isNoContent());
        getAs(author, base).andExpect(jsonPath("$.items[0].content").value("삭제된 댓글입니다."))
                .andExpect(jsonPath("$.items[0].is_deleted").value(true)).andExpect(jsonPath("$.total").value(4));
        getAs(author, "/api/posts/" + post).andExpect(jsonPath("$.comment_count").value(3));
        deleteAs(reader, base + "/" + second).andExpect(status().isNoContent());
        deleteAs(reader, base + "/" + second).andExpect(status().isNotFound());
        getAs(author, base).andExpect(jsonPath("$.total").value(3));
        deleteAs(reader, "/api/posts/" + otherPost + "/comments/" + root).andExpect(status().isNotFound());
    }

    @Test
    void likesAreExclusiveAndUnlikeIsIdempotent() throws Exception {
        TestUser user = newUser(true);
        TestUser other = newUser(true);
        long post = newPost(user, "info", "좋아요");
        postAs(user, "/api/posts/" + post + "/likes", null).andExpect(status().isOk())
                .andExpect(jsonPath("$.like_count").value(1)).andExpect(jsonPath("$.liked_by_me").value(true));
        postAs(user, "/api/posts/" + post + "/likes", null)
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ALREADY_LIKED"));
        postAs(other, "/api/posts/" + post + "/likes", null).andExpect(jsonPath("$.like_count").value(2));
        getAs(user, "/api/posts/" + post).andExpect(jsonPath("$.liked_by_me").value(true)).andExpect(jsonPath("$.like_count").value(2));
        deleteAs(user, "/api/posts/" + post + "/likes").andExpect(status().isOk())
                .andExpect(jsonPath("$.like_count").value(1)).andExpect(jsonPath("$.liked_by_me").value(false));
        deleteAs(user, "/api/posts/" + post + "/likes").andExpect(status().isOk()).andExpect(jsonPath("$.like_count").value(1));
        postAs(user, "/api/posts/999999/likes", null).andExpect(status().isNotFound());
        deleteAs(user, "/api/posts/999999/likes").andExpect(status().isNotFound());
    }

    @Test
    void threeDistinctReportersHideThePost() throws Exception {
        TestUser author = newUser(true);
        long post = newPost(author, "info", "신고글");
        String body = "{\"target_type\":\"post\",\"target_id\":" + post + ",\"reason\":\"spam\",\"detail\":\"광고\"}";
        postAs(author, "/api/reports", body).andExpect(status().isBadRequest());
        TestUser a = newUser(true);
        TestUser b = newUser(true);
        TestUser c = newUser(true);
        postAs(a, "/api/reports", body).andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("pending"))
                .andExpect(jsonPath("$.detail").value("광고"));
        postAs(a, "/api/reports", body).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ALREADY_REPORTED"));
        postAs(b, "/api/reports", body).andExpect(status().isCreated());
        getAs(c, "/api/posts/" + post).andExpect(status().isOk());
        postAs(c, "/api/reports", body.replace(",\"detail\":\"광고\"", "")).andExpect(status().isCreated())
                .andExpect(jsonPath("$.detail").doesNotExist());

        getAs(c, "/api/posts/" + post).andExpect(status().isNotFound());
        getAs(author, "/api/posts/" + post).andExpect(status().isOk());
        String list = getAs(c, "/api/posts").andReturn().getResponse().getContentAsString();
        assertThat((List<Integer>) JsonPath.read(list, "$.items[*].post_id")).doesNotContain((int) post);

        getAs(a, "/api/reports").andExpect(jsonPath("$.total").value(1)).andExpect(jsonPath("$.items[0].target_id").value(post));
        postAs(a, "/api/reports", "{\"target_type\":\"post\",\"target_id\":999999,\"reason\":\"spam\"}").andExpect(status().isNotFound());
        postAs(a, "/api/reports", "{\"target_type\":\"comment\",\"target_id\":999999,\"reason\":\"spam\"}").andExpect(status().isNotFound());
        postAs(a, "/api/reports", "{\"target_type\":\"post\",\"target_id\":1,\"reason\":\"bogus\"}").andExpect(status().isBadRequest());
        postAs(a, "/api/reports", "{\"target_type\":\"post\",\"target_id\":1}").andExpect(status().isBadRequest());
        postAs(a, "/api/reports", "{\"target_type\":\"post\",\"target_id\":" + post + ",\"reason\":\"spam\",\"detail\":\""
                + "가".repeat(201) + "\"}").andExpect(status().isBadRequest());
    }

    @Test
    void reportedCommentsAreHiddenFromList() throws Exception {
        TestUser author = newUser(true);
        long post = newPost(author, "info", "댓글신고");
        TestUser writer = newUser(true);
        long comment = readId(postAs(writer, "/api/posts/" + post + "/comments", "{\"content\":\"나쁜 말\"}")
                .andExpect(status().isCreated()), "$.comment_id");
        String body = "{\"target_type\":\"comment\",\"target_id\":" + comment + ",\"reason\":\"abuse\"}";
        for (int i = 0; i < 3; i++) {
            postAs(newUser(true), "/api/reports", body).andExpect(status().isCreated());
        }
        getAs(author, "/api/posts/" + post + "/comments").andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void blockingHidesPostsAndCommentsOfThatUser() throws Exception {
        TestUser me = newUser(true);
        TestUser troll = newUser(true);
        long trollPost = newPost(troll, "info", "트롤글");
        long okPost = newPost(newUser(true), "info", "정상글");
        postAs(troll, "/api/posts/" + okPost + "/comments", "{\"content\":\"트롤 댓글\"}").andExpect(status().isCreated());

        postAs(me, "/api/blocks/" + me.id(), null).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_BLOCK_SELF"));
        postAs(me, "/api/blocks/999999", null).andExpect(status().isNotFound());
        postAs(me, "/api/blocks/" + troll.id(), null).andExpect(status().isCreated())
                .andExpect(jsonPath("$.user_id").value(troll.id())).andExpect(jsonPath("$.nickname").isNotEmpty());
        postAs(me, "/api/blocks/" + troll.id(), null).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_BLOCKED"));

        String list = getAs(me, "/api/posts").andReturn().getResponse().getContentAsString();
        assertThat((List<Integer>) JsonPath.read(list, "$.items[*].post_id")).doesNotContain((int) trollPost).contains((int) okPost);
        getAs(me, "/api/posts/" + okPost + "/comments").andExpect(jsonPath("$.total").value(0));
        getAs(troll, "/api/posts/" + okPost + "/comments").andExpect(jsonPath("$.total").value(1));
        getAs(me, "/api/blocks").andExpect(jsonPath("$.total").value(1)).andExpect(jsonPath("$.items[0].user_id").value(troll.id()));

        deleteAs(me, "/api/blocks/" + troll.id()).andExpect(status().isNoContent());
        deleteAs(me, "/api/blocks/" + troll.id()).andExpect(status().isNoContent());
        deleteAs(me, "/api/blocks/999999").andExpect(status().isNotFound());
        getAs(me, "/api/blocks").andExpect(jsonPath("$.total").value(0));
        getAs(me, "/api/posts/" + trollPost).andExpect(status().isOk());
        getAs(newUser(false), "/api/blocks").andExpect(status().isForbidden());
    }

    @Test
    void withdrawalRemovesCommunityData() throws Exception {
        TestUser leaver = newUser(true);
        TestUser other = newUser(true);
        long post = readId(createPost(leaver, "info", "탈퇴글", "본문", image(1)).andExpect(status().isCreated()), "$.post_id");
        long comment = readId(postAs(other, "/api/posts/" + post + "/comments", "{\"content\":\"댓글\"}").andExpect(status().isCreated()), "$.comment_id");
        postAs(leaver, "/api/posts/" + post + "/comments", "{\"content\":\"답\",\"parent_id\":" + comment + "}").andExpect(status().isCreated());
        long otherPost = newPost(other, "info", "남은 글");
        postAs(leaver, "/api/posts/" + otherPost + "/likes", null).andExpect(status().isOk());
        postAs(leaver, "/api/posts/" + otherPost + "/comments", "{\"content\":\"탈퇴자 댓글\"}").andExpect(status().isCreated());
        postAs(leaver, "/api/blocks/" + other.id(), null).andExpect(status().isCreated());
        postAs(leaver, "/api/reports", "{\"target_type\":\"post\",\"target_id\":" + otherPost + ",\"reason\":\"spam\"}").andExpect(status().isCreated());

        deleteAs(leaver, "/api/users/me").andExpect(status().isNoContent());
        getAs(other, "/api/posts/" + post).andExpect(status().isNotFound());
        getAs(other, "/api/posts/" + otherPost).andExpect(status().isOk());
    }
}
