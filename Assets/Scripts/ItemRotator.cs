using System;
using System.Diagnostics.CodeAnalysis;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;

public class Item3dRotator : MonoBehaviour
{
    public event Action BeginDrag;

    [SerializeField, NotNull]
    private EventTrigger _eventTrigger;
    [SerializeField, NotNull]
    private Transform _itemHolder;

    [SerializeField] private bool _enabled = true;

    private void Awake()
    {
        AddEventTrigger(EventTriggerType.Drag, OnDrag);
        AddEventTrigger(EventTriggerType.BeginDrag, OnBeginDrag);
    }

    private void AddEventTrigger(EventTriggerType eventTriggerType, UnityAction<BaseEventData> call)
    {
        var eventTrigger = new EventTrigger.Entry() { eventID = eventTriggerType };
        eventTrigger.callback.AddListener(call);
        _eventTrigger.triggers.Add(eventTrigger);
    }

    private void OnDrag(BaseEventData data)
    {
        if (!_enabled)
            return;
        var castedData = data as PointerEventData;
        _itemHolder.transform.Rotate(Vector3.down, castedData.delta.x);
        _itemHolder.transform.Rotate(Vector3.right, castedData.delta.y);
    }

    private void OnBeginDrag(BaseEventData data)
    {
        if (!_enabled)
            return;
        BeginDrag?.Invoke();
    }
}