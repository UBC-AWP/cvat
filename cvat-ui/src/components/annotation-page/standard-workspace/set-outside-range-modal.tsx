// Copyright (C) CVAT.ai Corporation
//
// SPDX-License-Identifier: MIT

import React, { useState } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import Modal from 'antd/lib/modal';
import InputNumber from 'antd/lib/input-number';
import Text from 'antd/lib/typography/Text';
import { Row, Col } from 'antd/lib/grid';

import { CombinedState } from 'reducers';
import {
    switchSetOutsideRangeVisibility,
    setOutsideForRangeAsync,
} from 'actions/annotation-actions';

export default function SetOutsideRangeModal(): JSX.Element | null {
    const dispatch = useDispatch();
    const visible = useSelector((state: CombinedState) => state.annotation.setOutsideRange.visible);
    const frame = useSelector((state: CombinedState) => state.annotation.player.frame.number);
    const stopFrame = useSelector(
        (state: CombinedState) => state.annotation.job.instance?.stopFrame ?? 0,
    );

    const [rangeStart, setRangeStart] = useState<number>(frame);
    const [rangeEnd, setRangeEnd] = useState<number>(stopFrame);

    React.useEffect(() => {
        if (visible) {
            setRangeStart(frame);
            setRangeEnd(Math.min(frame + 100, stopFrame));
        }
    }, [visible, frame, stopFrame]);

    if (!visible) return null;

    return (
        <Modal
            title='Set outside for range'
            open={visible}
            onOk={() => {
                const clampedEnd = Math.min(rangeEnd, stopFrame);
                dispatch(setOutsideForRangeAsync(rangeStart, clampedEnd));
                dispatch(switchSetOutsideRangeVisibility(false));
            }}
            onCancel={() => dispatch(switchSetOutsideRangeVisibility(false))}
            okText='Apply'
            cancelText='Cancel'
        >
            <Row align='middle' style={{ marginBottom: 12 }}>
                <Col span={8}><Text>Start frame:</Text></Col>
                <Col span={16}>
                    <InputNumber
                        style={{ width: '100%' }}
                        min={0}
                        max={stopFrame}
                        value={rangeStart}
                        onChange={(val) => setRangeStart(val ?? frame)}
                    />
                </Col>
            </Row>
            <Row align='middle'>
                <Col span={8}><Text>End frame:</Text></Col>
                <Col span={16}>
                    <InputNumber
                        style={{ width: '100%' }}
                        min={rangeStart}
                        max={stopFrame}
                        value={rangeEnd}
                        onChange={(val) => setRangeEnd(val ?? stopFrame)}
                    />
                </Col>
            </Row>
        </Modal>
    );
}
